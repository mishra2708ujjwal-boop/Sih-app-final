"""
prana_ml/scripts/parse_bidmc.py

Parses the BIDMC PPG and Respiration Dataset's Numerics CSVs into the
frozen 16-feature schema. Populates only features 0, 1, 2, 3, 15 — the
ones BIDMC can legitimately support (see Phase 2 dataset research doc).
All other features are left as NaN, not fabricated.

Per-subject baseline is derived from that subject's OWN recording
(median PULSE as the baseline midpoint proxy, 5th-percentile SpO2 as the
baseline-minimum proxy) — mirroring how the on-device system learns a
personal baseline from that user's own history, rather than assuming a
population constant.

Uses PULSE (PPG-derived), not HR (ECG-derived), as the heart-rate proxy,
since the ESP32's MAX30102 is a PPG sensor, not ECG. HR is kept only for
a quality-control cross-check against PULSE.
"""

import glob
import os
import numpy as np
import pandas as pd

from feature_constants import (
    HR_MIN_BPM, HR_RANGE_BPM, HR_DEV_CLAMP_MIN, HR_DEV_CLAMP_MAX,
    SPO2_MIN_PCT, SPO2_RANGE_PCT, SPO2_DROP_CLAMP_MAX, SPO2_DROP_DIVISOR,
    TREND_SLOPE_CLAMP_MIN, TREND_SLOPE_CLAMP_MAX,
    TREND_NORMALIZATION_BPM_PER_MIN,
)
from baseline_utils import clamp, rolling_trend_slope
from feature_schema import OUTPUT_COLUMNS, FEATURE_NAMES

# Resolve paths relative to prana_ml/ (this script's parent dir),
# not relative to whatever directory you happen to run it from.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)

BIDMC_DIR = os.path.join(ROOT_DIR, "data", "raw", "bidmc",
                          "bidmc-ppg-and-respiration-dataset-1.0.0", "bidmc_csv")
PROCESSED_DIR = os.path.join(ROOT_DIR, "data", "processed")

WINDOW_SECONDS = 10
HR_PULSE_QC_MAX_DIFF_BPM = 10  # drop windows where ECG HR and PPG pulse disagree this much


def parse_one_subject(numerics_path, subject_id):
    df = pd.read_csv(numerics_path, skipinitialspace=True)
    df = df.rename(columns={"Time [s]": "time_s"})
    df = df.dropna(subset=["time_s", "HR", "PULSE", "SpO2"])

    # QC: drop samples where ECG HR and PPG pulse rate disagree —
    # indicates a bad pleth trace, not a real physiological signal.
    df = df[(df["HR"] - df["PULSE"]).abs() <= HR_PULSE_QC_MAX_DIFF_BPM]
    if len(df) == 0:
        return None

    # Personal baseline derived from this subject's own recording.
    baseline_hr_mid = df["PULSE"].median()
    baseline_spo2_min = df["SpO2"].quantile(0.05)

    # Bucket into fixed windows and average within each.
    df["window_idx"] = (df["time_s"] // WINDOW_SECONDS).astype(int)
    grouped = df.groupby("window_idx").agg(
        window_start_s=("time_s", "min"),
        mean_pulse=("PULSE", "mean"),
        mean_spo2=("SpO2", "mean"),
    ).reset_index(drop=True)

    if len(grouped) == 0:
        return None

    slopes = rolling_trend_slope(
        grouped["window_start_s"].tolist(), grouped["mean_pulse"].tolist()
    )

    rows = []
    for i, r in grouped.iterrows():
        f0 = clamp((r.mean_pulse - HR_MIN_BPM) / HR_RANGE_BPM, 0.0, 1.0)
        f1 = clamp(
            (r.mean_pulse - baseline_hr_mid) / baseline_hr_mid,
            HR_DEV_CLAMP_MIN, HR_DEV_CLAMP_MAX,
        )
        f2 = clamp((r.mean_spo2 - SPO2_MIN_PCT) / SPO2_RANGE_PCT, 0.0, 1.0)
        raw_drop = clamp(baseline_spo2_min - r.mean_spo2, 0.0, SPO2_DROP_CLAMP_MAX)
        f3 = raw_drop / SPO2_DROP_DIVISOR

        slope = slopes[i]
        if slope is None:
            f15 = np.nan
        else:
            f15 = clamp(
                slope / TREND_NORMALIZATION_BPM_PER_MIN,
                TREND_SLOPE_CLAMP_MIN, TREND_SLOPE_CLAMP_MAX,
            )

        feature_values = {name: np.nan for name in FEATURE_NAMES}
        feature_values.update({
            "normalized_hr": f0,
            "hr_baseline_deviation": f1,
            "normalized_spo2": f2,
            "spo2_baseline_drop": f3,
            "hr_trend_slope": f15,
        })

        row = {
            "source_dataset": "bidmc",
            "subject_id": subject_id,
            "window_start_s": r.window_start_s,
        }
        row.update(feature_values)
        rows.append(row)

    return pd.DataFrame(rows, columns=OUTPUT_COLUMNS)


def main():
    numerics_files = sorted(glob.glob(os.path.join(BIDMC_DIR, "bidmc_*_Numerics.csv")))
    if not numerics_files:
        raise SystemExit(f"No Numerics CSVs found under {BIDMC_DIR} — check the path.")

    all_dfs = []
    for path in numerics_files:
        subject_id = os.path.basename(path).split("_")[1]  # e.g. "01"
        result = parse_one_subject(path, subject_id)
        if result is not None:
            all_dfs.append(result)
        else:
            print(f"  WARNING: subject {subject_id} produced no usable windows, skipped")

    combined = pd.concat(all_dfs, ignore_index=True)
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    out_path = os.path.join(PROCESSED_DIR, "bidmc_features.csv")
    combined.to_csv(out_path, index=False)

    print(f"Parsed {len(numerics_files)} subjects -> {len(combined)} rows")
    print(f"Written to {out_path}")
    print(combined[["normalized_hr", "hr_baseline_deviation", "normalized_spo2",
                     "spo2_baseline_drop", "hr_trend_slope"]].describe())


if __name__ == "__main__":
    main()