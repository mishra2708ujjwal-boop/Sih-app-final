"""What we're changing: Replacing the naive "all files already match" assumption with an explicit rename map per source, and dropping each file's own source_dataset/subject_id columns in favor of the loop's authoritative source name (so we're never trusting two different tagging conventions at once)."""
import os

import pandas as pd

PROCESSED_DIR = os.path.join("..", "data", "processed")

# Canonical schema — adopted from BIDMC/MMASH's existing naming since two of
# three source files already agree on it.
CANONICAL_FEATURE_COLUMNS = [
    "normalized_hr", "hr_baseline_deviation",
    "normalized_spo2", "spo2_baseline_drop",
    "normalized_body_temp", "body_temp_deviation",
    "activity_level",
    "sleep_duration_ratio", "sleep_quality",
    "ambient_temp", "humidity", "aqi", "heat_index", "heat_exposure_duration",
    "hrv_rmssd", "hr_trend_slope",
]

# Each source's REAL on-disk header mapped explicitly to the canonical name.
# Only columns that differ need an entry; anything already canonical is
# passed through unchanged. This is deliberately explicit (not "rename
# whatever doesn't match") so a genuinely new/unexpected column raises an
# error instead of being silently dropped or mismapped.
SOURCES = {
    "bidmc": {
        "filename": "bidmc_features.csv",
        "rename": {"window_start_s": "window_start_s"},  # already canonical
    },
    "mmash": {
        "filename": "mmash_features.csv",
        "rename": {"window_start_s": "window_start_s"},  # already canonical
    },
    "ppg_dalia": {
        "filename": "ppg_dalia_features.csv",
        "rename": {
            "normalized_temp": "normalized_body_temp",
            "temp_baseline_deviation": "body_temp_deviation",
            "window_start_sec": "window_start_s",
        },
    },
}


def load_and_tag(source_name, config):
    path = os.path.join(PROCESSED_DIR, config["filename"])
    df = pd.read_csv(path)

    if config["rename"]:
        df = df.rename(columns=config["rename"])

    # Ignore whatever tagging the file already carries (e.g. BIDMC/MMASH's
    # own "source_dataset" column) — the loop key here is the single source
    # of truth for which dataset a row came from.
    df["dataset_source"] = source_name
    df["global_subject_id"] = source_name + "_" + df["subject_id"].astype(str)

    missing_cols = [c for c in CANONICAL_FEATURE_COLUMNS if c not in df.columns]
    if missing_cols:
        raise ValueError(
            f"{config['filename']} is missing expected columns after rename: "
            f"{missing_cols}. Actual columns: {list(df.columns)}"
        )

    return df[["global_subject_id", "dataset_source"] + CANONICAL_FEATURE_COLUMNS]


def main():
    all_dfs = []
    for source_name, config in SOURCES.items():
        df = load_and_tag(source_name, config)
        print(f"{source_name}: {len(df)} rows, {df['global_subject_id'].nunique()} subjects")
        all_dfs.append(df)

    combined = pd.concat(all_dfs, ignore_index=True)

    out_path = os.path.join(PROCESSED_DIR, "combined_features.csv")
    combined.to_csv(out_path, index=False)
    print(f"\nCombined: {len(combined)} rows, "
          f"{combined['global_subject_id'].nunique()} unique subjects total")
    print(f"Written to {out_path}")

    print("\n" + "=" * 70)
    print("FEATURE COVERAGE BY DATASET (% of rows with a real, non-NaN value)")
    print("=" * 70)
    coverage = combined.groupby("dataset_source")[CANONICAL_FEATURE_COLUMNS].apply(
        lambda g: g.notna().mean() * 100
    )
    pd.set_option("display.width", 200)
    pd.set_option("display.max_columns", None)
    print(coverage.round(1).T)

    print("\n" + "=" * 70)
    print("FEATURES WITH 100% COVERAGE ACROSS *ALL THREE* DATASETS")
    print("=" * 70)
    fully_covered = [c for c in CANONICAL_FEATURE_COLUMNS if (coverage[c] >= 99.9).all()]
    for c in fully_covered:
        print(f"  - {c}")
    if not fully_covered:
        print("  (none — see per-dataset breakdown above)")


if __name__ == "__main__":
    main()