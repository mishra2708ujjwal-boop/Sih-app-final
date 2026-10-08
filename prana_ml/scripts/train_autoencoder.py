import os

import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

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
MASK_COLUMNS = [f"{c}_present" for c in FEATURE_COLUMNS]
N_FEATURES = len(FEATURE_COLUMNS)   # 11
INPUT_DIM = N_FEATURES * 2          # 22 (features + mask)

LATENT_DIM = 4
EPOCHS = 100
BATCH_SIZE = 256
PATIENCE = 10
SEED = 42

tf.random.set_seed(SEED)
np.random.seed(SEED)


def load_split(df, split_name):
    subset = df[df["split"] == split_name]
    X = subset[FEATURE_COLUMNS].to_numpy(dtype=np.float32)
    M = subset[MASK_COLUMNS].to_numpy(dtype=np.float32)
    model_input = np.concatenate([X, M], axis=1)          # what the model SEES
    target = np.concatenate([X, M], axis=1)                # what the loss needs (true values + mask)
    dataset_source = subset["dataset_source"].to_numpy()
    return model_input, target, dataset_source


def apply_mask_dropout(model_input, target, min_drop=0.15, max_drop=0.40, seed=None):
    """Randomly zero out additional (value, mask) pairs among features that
    were ALREADY present, per row, at a random rate between min_drop and
    max_drop. This is applied ONLY to model_input/target's mask-derived
    view here -- it augments the fixed 3 dataset-native mask patterns into
    a much wider variety of combinations, so the network learns to
    reconstruct from arbitrary sensor subsets rather than memorizing
    exactly BIDMC's/MMASH's/PPG-DaLiA's shapes. This directly targets the
    Diagnostic 3 failure: a mask combination the live ESP32 app produces
    that doesn't match any single training dataset's fixed pattern.
    """
    rng = np.random.default_rng(seed)
    n_rows = model_input.shape[0]

    values = model_input[:, :N_FEATURES].copy()
    mask = model_input[:, N_FEATURES:].copy()

    drop_rate = rng.uniform(min_drop, max_drop, size=(n_rows, 1))
    random_drop = rng.random((n_rows, N_FEATURES)) < drop_rate
    # Only drop where a value was actually present -- can't "drop" what was
    # already absent, that's a no-op, not new information for the model.
    actual_drop = random_drop & (mask == 1.0)

    values[actual_drop] = 0.0
    mask[actual_drop] = 0.0

    augmented_input = np.concatenate([values, mask], axis=1)
    # Target keeps the ORIGINAL real values + ORIGINAL mask -- the loss
    # should never be computed against an artificially-dropped value, only
    # against genuinely real ones. Re-dropping the target would teach the
    # model to reconstruct zeros, which is wrong.
    return augmented_input, target

def compute_sample_weights(dataset_source):
    """Inverse-frequency weighting so BIDMC (2.6% of train rows) influences
    the loss as much as PPG-DaLiA (68.9%) and MMASH (28.5%), rather than
    being drowned out. Weights are normalized to average 1.0 so the
    effective learning rate/loss scale doesn't change."""
    unique, counts = np.unique(dataset_source, return_counts=True)
    freq = dict(zip(unique, counts))
    n_sources = len(unique)
    weights = np.array([
        len(dataset_source) / (n_sources * freq[src]) for src in dataset_source
    ], dtype=np.float32)
    return weights


def masked_mse_per_sample(y_true, y_pred):
    """y_true is [real_values(11) | mask(11)] = 22-dim.
    y_pred is the model's reconstruction of the 11 real features only.
    Loss is computed ONLY over features that were actually present
    (mask=1) — the model is never penalized for failing to reconstruct a
    value that was never really measured for that row."""
    real_values = y_true[:, :N_FEATURES]
    mask = y_true[:, N_FEATURES:]
    sq_err = tf.square(real_values - y_pred) * mask
    per_sample = tf.reduce_sum(sq_err, axis=1) / (tf.reduce_sum(mask, axis=1) + 1e-8)
    return per_sample


def build_model():
    inputs = keras.Input(shape=(INPUT_DIM,), name="features_and_mask")
    x = layers.Dense(16, activation="relu")(inputs)
    x = layers.Dense(8, activation="relu")(x)
    latent = layers.Dense(LATENT_DIM, activation="relu", name="latent")(x)
    x = layers.Dense(8, activation="relu")(latent)
    x = layers.Dense(16, activation="relu")(x)
    # Linear output — several features range beyond [0,1] (deviations go to
    # [-1,2], trend slope to [-2,2]); a bounded activation would clip them.
    outputs = layers.Dense(N_FEATURES, activation="linear", name="reconstruction")(x)
    return keras.Model(inputs, outputs, name="prana_anomaly_autoencoder")


def main():
    df = pd.read_csv(os.path.join(PROCESSED_DIR, "training_matrix.csv"))

    X_train, y_train, src_train = load_split(df, "train")
    X_val, y_val, _ = load_split(df, "val")
    X_test, y_test, src_test = load_split(df, "test")

    # Augment ONLY the training set. Val/test stay as real, unmodified
    # dataset-native mask patterns, since they're what we use to judge the
    # model honestly -- augmenting them too would make validation loss
    # measure something other than real generalization.
    X_train, y_train = apply_mask_dropout(X_train, y_train, seed=SEED)

    sample_weights = compute_sample_weights(src_train)

    print(f"Train: {X_train.shape}, Val: {X_val.shape}, Test: {X_test.shape}")
    print(f"Sample weight range: [{sample_weights.min():.3f}, {sample_weights.max():.3f}]")

    model = build_model()
    model.compile(optimizer=keras.optimizers.Adam(learning_rate=1e-3),
                   loss=masked_mse_per_sample)
    model.summary()

    os.makedirs(MODELS_DIR, exist_ok=True)
    checkpoint_path = os.path.join(MODELS_DIR, "prana_autoencoder_best.keras")

    callbacks = [
        keras.callbacks.EarlyStopping(monitor="val_loss", patience=PATIENCE,
                                       restore_best_weights=True),
        keras.callbacks.ModelCheckpoint(checkpoint_path, monitor="val_loss",
                                         save_best_only=True),
    ]

    history = model.fit(
        X_train, y_train,
        sample_weight=sample_weights,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=callbacks,
        verbose=2,
    )

    # Final held-out evaluation — overall AND per-dataset, since a single
    # blended number would hide exactly the kind of imbalance we just
    # weighted against during training.
    test_loss = model.evaluate(X_test, y_test, verbose=0)
    print(f"\nOverall test masked MSE: {test_loss:.5f}")

    print("\nPer-dataset test masked MSE:")
    for source in np.unique(src_test):
        idx = src_test == source
        loss = model.evaluate(X_test[idx], y_test[idx], verbose=0)
        print(f"  {source}: {loss:.5f}  (n={idx.sum()})")

    history_path = os.path.join(MODELS_DIR, "training_history.csv")
    pd.DataFrame(history.history).to_csv(history_path, index=False)
    print(f"\nBest model saved to {checkpoint_path}")
    print(f"Training history saved to {history_path}")


if __name__ == "__main__":
    main()