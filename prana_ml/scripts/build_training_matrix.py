"""What we're changing: Takes combined_features.csv, drops the 5 untrainable environment columns, adds an 11-bit presence mask (1 per physiological feature, per row), imputes missing values to 0.0 (safe only because the mask tells the model which zeros are real vs. absent — never presented as a real reading), and performs the subject-level train/val/test split your Phase 3 rules require (no subject's rows appearing in more than one split)."""
import os

import numpy as np
import pandas as pd

PROCESSED_DIR = os.path.join("..", "data", "processed")

# Environment features excluded entirely — 0% coverage in all 3 datasets,
# see Checkpoint C part 1 findings. Not trainable from this data.
PHYSIOLOGICAL_FEATURES = [
    "normalized_hr", "hr_baseline_deviation",
    "normalized_spo2", "spo2_baseline_drop",
    "normalized_body_temp", "body_temp_deviation",
    "activity_level",
    "sleep_duration_ratio", "sleep_quality",
    "hrv_rmssd", "hr_trend_slope",
]

TRAIN_FRAC, VAL_FRAC = 0.70, 0.15  # remaining 0.15 -> test


def subject_level_split(subject_ids, seed=42):
    rng = np.random.default_rng(seed)
    shuffled = list(subject_ids)
    rng.shuffle(shuffled)
    n = len(shuffled)
    n_train = int(n * TRAIN_FRAC)
    n_val = int(n * VAL_FRAC)
    return (
        set(shuffled[:n_train]),
        set(shuffled[n_train:n_train + n_val]),
        set(shuffled[n_train + n_val:]),
    )


def main():
    df = pd.read_csv(os.path.join(PROCESSED_DIR, "combined_features.csv"))

    # Presence mask BEFORE imputation — 1.0 where a real value exists.
    for col in PHYSIOLOGICAL_FEATURES:
        df[f"{col}_present"] = df[col].notna().astype(float)

    # Impute only after the mask is captured. 0.0 is safe here because the
    # model always sees the mask alongside it — it is never told "this is a
    # real zero reading" for an absent sensor.
    df[PHYSIOLOGICAL_FEATURES] = df[PHYSIOLOGICAL_FEATURES].fillna(0.0)

    # Subject-level split — split on global_subject_id, never on rows, so no
    # subject's data leaks across train/val/test.
    train_ids, val_ids, test_ids = subject_level_split(
        sorted(df["global_subject_id"].unique())
    )

    df["split"] = df["global_subject_id"].apply(
        lambda sid: "train" if sid in train_ids
        else "val" if sid in val_ids
        else "test"
    )

    out_path = os.path.join(PROCESSED_DIR, "training_matrix.csv")
    df.to_csv(out_path, index=False)

    print(f"Total rows: {len(df)}")
    print(f"Total subjects: {df['global_subject_id'].nunique()}")
    print()
    for split_name in ["train", "val", "test"]:
        subset = df[df["split"] == split_name]
        n_subjects = subset["global_subject_id"].nunique()
        print(f"{split_name}: {len(subset)} rows, {n_subjects} subjects")

    print("\nLeakage check (should ALL be empty sets):")
    print(f"  train ∩ val:  {train_ids & val_ids}")
    print(f"  train ∩ test: {train_ids & test_ids}")
    print(f"  val ∩ test:   {val_ids & test_ids}")

    print("\nPer-dataset representation in each split:")
    print(pd.crosstab(df["split"], df["dataset_source"]))

    print(f"\nWritten to {out_path}")
    print(f"Input dimensionality for the model: {len(PHYSIOLOGICAL_FEATURES)} "
          f"features + {len(PHYSIOLOGICAL_FEATURES)} mask bits = "
          f"{len(PHYSIOLOGICAL_FEATURES) * 2}-dim")


if __name__ == "__main__":
    main()