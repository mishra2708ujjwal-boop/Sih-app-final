import os

import numpy as np
import pandas as pd
import tensorflow as tf

PROCESSED_DIR = os.path.join("..", "data", "processed")
MODELS_DIR = os.path.join("..", "models")

FEATURE_COLUMNS = [
    "normalized_hr", "hr_baseline_deviation",
    "normalized_spo2", "spo2_baseline_drop",
    "normalized_body_temp", "body_temp_deviation",
    "activity_level",
    "sleep_duration_ratio", "sleep_quality",
    "hrv_rmssd", "hr_trend_slope",
]
N_FEATURES = len(FEATURE_COLUMNS)


def masked_mse_per_sample(y_true, y_pred):
    real_values = y_true[:, :N_FEATURES]
    mask = y_true[:, N_FEATURES:]
    sq_err = np.square(real_values - y_pred) * mask
    return np.sum(sq_err, axis=1) / (np.sum(mask, axis=1) + 1e-8)


# The three mask patterns that actually existed in training — anything
# else is untested territory for this model, which is itself today's key
# finding (see checkpoint notes).
NATIVE_MASKS = {
    "bidmc": {"normalized_hr": 1, "hr_baseline_deviation": 1,
              "normalized_spo2": 1, "spo2_baseline_drop": 1,
              "normalized_body_temp": 0, "body_temp_deviation": 0,
              "activity_level": 0, "sleep_duration_ratio": 0, "sleep_quality": 0,
              "hrv_rmssd": 0, "hr_trend_slope": 1},
    "mmash": {"normalized_hr": 1, "hr_baseline_deviation": 1,
              "normalized_spo2": 0, "spo2_baseline_drop": 0,
              "normalized_body_temp": 0, "body_temp_deviation": 0,
              "activity_level": 1, "sleep_duration_ratio": 1, "sleep_quality": 1,
              "hrv_rmssd": 1, "hr_trend_slope": 1},
    "ppg_dalia": {"normalized_hr": 1, "hr_baseline_deviation": 1,
                  "normalized_spo2": 0, "spo2_baseline_drop": 0,
                  "normalized_body_temp": 1, "body_temp_deviation": 1,
                  "activity_level": 1, "sleep_duration_ratio": 0, "sleep_quality": 0,
                  "hrv_rmssd": 1, "hr_trend_slope": 1},
}


def make_vector(overrides, mask_present):
    base = {
        "normalized_hr": 0.31, "hr_baseline_deviation": 0.0,
        "normalized_spo2": 0.93, "spo2_baseline_drop": 0.0,
        "normalized_body_temp": 0.33, "body_temp_deviation": 0.0,
        "activity_level": 0.5,
        "sleep_duration_ratio": 0.7, "sleep_quality": 0.85,
        "hrv_rmssd": 0.3, "hr_trend_slope": 0.0,
    }
    base.update(overrides)
    mask_list = [mask_present.get(c, 1.0) for c in FEATURE_COLUMNS]
    # Match build_training_matrix.py's exact convention: wherever a feature
    # is absent (mask=0), its value MUST be 0.0 — that is the only input
    # combination the network was ever trained on for that position. Using
    # any other placeholder there (as the previous version of this script
    # did) feeds the model a combination it has never seen and produces a
    # meaningless error spike unrelated to whether the READING is anomalous.
    value_list = [
        (base[c] if mask_list[i] == 1.0 else 0.0)
        for i, c in enumerate(FEATURE_COLUMNS)
    ]
    values = np.array([value_list], dtype=np.float32)
    mask = np.array([mask_list], dtype=np.float32)
    return values, mask


def main():
    model = tf.keras.models.load_model(
        os.path.join(MODELS_DIR, "prana_autoencoder_best.keras"),
        custom_objects={"masked_mse_per_sample": masked_mse_per_sample},
        compile=False,
    )

    df = pd.read_csv(os.path.join(PROCESSED_DIR, "training_matrix.csv"))
    test = df[df["split"] == "test"]
    X_test = test[FEATURE_COLUMNS].to_numpy(dtype=np.float32)
    M_test = test[[f"{c}_present" for c in FEATURE_COLUMNS]].to_numpy(dtype=np.float32)
    recon_test = model.predict(np.concatenate([X_test, M_test], axis=1), verbose=0)
    err_test = masked_mse_per_sample(np.concatenate([X_test, M_test], axis=1), recon_test)

    print("REAL TEST DATA reconstruction-error distribution:")
    print(f"  p50={np.percentile(err_test, 50):.5f}  "
          f"p90={np.percentile(err_test, 90):.5f}  "
          f"p95={np.percentile(err_test, 95):.5f}  "
          f"p99={np.percentile(err_test, 99):.5f}  "
          f"max={err_test.max():.5f}")

    def score_row(values, mask, err_test):
        recon = model.predict(np.concatenate([values, mask], axis=1), verbose=0)
        err = masked_mse_per_sample(np.concatenate([values, mask], axis=1), recon)[0]
        percentile = (err_test < err).mean() * 100
        return err, percentile

    print("\n=== DIAGNOSTIC 1: NATIVE masks, TYPICAL values (expect LOW, near p50) ===")
    for dataset_name, mask_pattern in NATIVE_MASKS.items():
        values, mask = make_vector({}, mask_pattern)
        err, pct = score_row(values, mask, err_test)
        print(f"  [{dataset_name} mask] typical values: error={err:.5f}  (~{pct:.1f}th pct)")

    print("\n=== DIAGNOSTIC 2: NATIVE masks, IMPLAUSIBLE values (expect HIGH, above p95) ===")
    implausible_by_dataset = {
        "bidmc": {"activity_level": 0.0, "normalized_spo2": 0.5, "spo2_baseline_drop": 2.8},
        "mmash": {"activity_level": 0.0, "normalized_hr": 0.85, "hr_baseline_deviation": 1.8},
        "ppg_dalia": {"activity_level": 0.85, "normalized_hr": 0.15, "hr_baseline_deviation": -0.9},
    }
    for dataset_name, mask_pattern in NATIVE_MASKS.items():
        values, mask = make_vector(implausible_by_dataset[dataset_name], mask_pattern)
        err, pct = score_row(values, mask, err_test)
        print(f"  [{dataset_name} mask] implausible values: error={err:.5f}  (~{pct:.1f}th pct)")

    print("\n=== DIAGNOSTIC 3: the ORIGINAL all-ones mask (never seen in training) ===")
    values, mask = make_vector({}, {c: 1.0 for c in FEATURE_COLUMNS})
    err, pct = score_row(values, mask, err_test)
    print(f"  [all-present mask] typical values: error={err:.5f}  (~{pct:.1f}th pct)")
    print("  (this is expected to be far higher than Diagnostic 1 if the mask")
    print("   pattern itself, not the values, was the cause)")


if __name__ == "__main__":
    main()