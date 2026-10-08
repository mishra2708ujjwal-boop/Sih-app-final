"""What we're changing: Building the third and final per-dataset parser, following the same pattern as parse_bidmc.py and parse_mmash.py — real signals in, frozen-schema features out, NaN for anything this dataset genuinely can't support.
"""
import glob
import os
import pickle

import numpy as np
import pandas as pd

from feature_constants import (
    HR_MIN_BPM, HR_RANGE_BPM,
    HR_DEV_CLAMP_MIN, HR_DEV_CLAMP_MAX,
    TEMP_MIN_C, TEMP_RANGE_C,
    TEMP_DEV_DIVISOR, TEMP_DEV_CLAMP_MIN, TEMP_DEV_CLAMP_MAX,
    ACTIVITY_REST, ACTIVITY_LOW, ACTIVITY_MODERATE_DEFAULT, ACTIVITY_HIGH,
    HRV_MAX_MS,
    TREND_SLOPE_CLAMP_MIN, TREND_SLOPE_CLAMP_MAX,
    TREND_NORMALIZATION_BPM_PER_MIN, TREND_MIN_SAMPLES, TREND_MAX_SAMPLES,
)

PPG_DALIA_DIR = os.path.join("..", "data", "raw", "ppg_dalia", "PPG_FieldStudy")
PROCESSED_DIR = os.path.join("..", "data", "processed")

CHEST_HZ = 700
WRIST_4HZ = 4
WINDOW_SEC = 8
SHIFT_SEC = 2
SAMPLES_PER_SHIFT_4HZ = WRIST_4HZ * SHIFT_SEC   # 8
SAMPLES_PER_WINDOW_4HZ = WRIST_4HZ * WINDOW_SEC  # 32

# PPG-DaLiA's official activity codes (verified against the dataset's own
# study-protocol description, not guessed): 0 = transient/no activity.
ACTIVITY_CODE_MAP = {
    0: ACTIVITY_REST,             # transient / between-activity period
    1: ACTIVITY_LOW,              # Sitting still, reading
    2: ACTIVITY_HIGH,             # Ascending/descending stairs
    3: ACTIVITY_HIGH,             # Table soccer
    4: ACTIVITY_HIGH,             # Cycling
    5: ACTIVITY_MODERATE_DEFAULT, # Driving a car
    6: ACTIVITY_REST,             # Lunch break
    7: ACTIVITY_MODERATE_DEFAULT, # Walking
    8: ACTIVITY_MODERATE_DEFAULT, # Working (desk work)
}


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def compute_hr_trend_slope(hr_values, hr_times_min):
    """Same least-squares formula as FeatureSchema/HrTrendCalculator, just
    fed with this dataset's actual timestamps instead of a live buffer."""
    n = len(hr_values)
    if n < TREND_MIN_SAMPLES:
        return np.nan

    xs = np.array(hr_times_min[-TREND_MAX_SAMPLES:])
    ys = np.array(hr_values[-TREND_MAX_SAMPLES:])
    xs = xs - xs[0]

    x_mean = xs.mean()
    y_mean = ys.mean()
    denom = np.sum((xs - x_mean) ** 2)
    if denom == 0:
        return 0.0

    slope_bpm_per_min = np.sum((xs - x_mean) * (ys - y_mean)) / denom
    normalized = slope_bpm_per_min / TREND_NORMALIZATION_BPM_PER_MIN
    return clamp(normalized, TREND_SLOPE_CLAMP_MIN, TREND_SLOPE_CLAMP_MAX)


def compute_rmssd(rpeak_times_sec, window_start, window_end):
    """RMSSD from REAL R-peak timestamps inside this window. Returns NaN
    (not a fabricated number) when there aren't enough peaks to compute at
    least one successive difference reliably."""
    in_window = rpeak_times_sec[
        (rpeak_times_sec >= window_start) & (rpeak_times_sec < window_end)
    ]
    if len(in_window) < 3:
        return np.nan
    rr_ms = np.diff(in_window) * 1000.0
    diffs = np.diff(rr_ms)
    return float(np.sqrt(np.mean(diffs ** 2)))


def parse_one_subject(subject_id):
    path = os.path.join(PPG_DALIA_DIR, subject_id, f"{subject_id}.pkl")
    with open(path, "rb") as f:
        data = pickle.load(f, encoding="latin1")

    hr_label = np.asarray(data["label"]).flatten()          # ground-truth HR, one per 2s shift
    wrist_temp = np.asarray(data["signal"]["wrist"]["TEMP"]).flatten()
    activity_raw = np.asarray(data["activity"]).flatten()
    rpeaks_sample_idx = np.asarray(data["rpeaks"]).flatten()
    rpeak_times_sec = rpeaks_sample_idx / CHEST_HZ

    n_windows = len(hr_label)
    max_wrist_idx = len(wrist_temp)

    # Per-subject baseline: mean HR during "Sitting" (activity code 1),
    # mirroring BaselineService's real rest-based calibration rather than
    # inventing a fixed constant. Falls back to the subject's overall
    # median HR if they never had a Sitting window (shouldn't happen per
    # the protocol, but guarded rather than assumed).
    sitting_windows = []
    for i in range(n_windows):
        start_idx = SAMPLES_PER_SHIFT_4HZ * i
        end_idx = start_idx + SAMPLES_PER_WINDOW_4HZ
        if end_idx > max_wrist_idx:
            break
        codes, counts = np.unique(
            activity_raw[start_idx:end_idx].astype(int), return_counts=True
        )
        mode_code = int(codes[np.argmax(counts)])
        if mode_code == 1:
            sitting_windows.append(hr_label[i])

    if sitting_windows:
        hr_baseline_mid = float(np.mean(sitting_windows))
    else:
        hr_baseline_mid = float(np.median(hr_label))

    rows = []
    hr_history_values = []
    hr_history_times_min = []

    for i in range(n_windows):
        start_idx = SAMPLES_PER_SHIFT_4HZ * i
        end_idx = start_idx + SAMPLES_PER_WINDOW_4HZ
        if end_idx > max_wrist_idx:
            # This is the known "one subject only valid for ~90 min"
            # hardware fault surfacing, or simply the tail end running out
            # of wrist samples — stop rather than read past the array.
            break

        window_start_sec = i * SHIFT_SEC
        window_end_sec = window_start_sec + WINDOW_SEC

        hr = float(hr_label[i])
        if not np.isfinite(hr) or hr <= 0:
            continue

        # Feature 0/1: HR norm + baseline deviation
        f0 = clamp((hr - HR_MIN_BPM) / HR_RANGE_BPM, 0.0, 1.0)
        f1 = clamp((hr - hr_baseline_mid) / hr_baseline_mid,
                   HR_DEV_CLAMP_MIN, HR_DEV_CLAMP_MAX)

        # Feature 4/5: body temperature (WRIST SKIN TEMP PROXY — not core
        # body temperature; see checkpoint notes)
        temp_window = wrist_temp[start_idx:end_idx]
        temp_c = float(np.mean(temp_window))
        f4 = clamp((temp_c - TEMP_MIN_C) / TEMP_RANGE_C, 0.0, 1.0)
        # No personal baseline-max for temp in this dataset; use the
        # subject's own session max as the closest available proxy.
        temp_baseline_max = float(np.max(wrist_temp))
        f5 = clamp((temp_c - temp_baseline_max) / TEMP_DEV_DIVISOR,
                   TEMP_DEV_CLAMP_MIN, TEMP_DEV_CLAMP_MAX)

        # Feature 6: activity, from PPG-DaLiA's real logged activity codes
        activity_window = activity_raw[start_idx:end_idx].astype(int)
        codes, counts = np.unique(activity_window, return_counts=True)
        mode_code = int(codes[np.argmax(counts)])
        f6 = ACTIVITY_CODE_MAP.get(mode_code, ACTIVITY_MODERATE_DEFAULT)

        # Feature 14: HRV RMSSD from real chest-ECG R-peaks
        rmssd_ms = compute_rmssd(rpeak_times_sec, window_start_sec, window_end_sec)
        f14 = clamp(rmssd_ms / HRV_MAX_MS, 0.0, 1.0) if np.isfinite(rmssd_ms) else np.nan

        # Feature 15: real trend slope from this subject's own HR history so far
        hr_history_values.append(hr)
        hr_history_times_min.append(window_start_sec / 60.0)
        f15 = compute_hr_trend_slope(hr_history_values, hr_history_times_min)

        rows.append({
            "subject_id": subject_id,
            "window_start_sec": window_start_sec,
            "normalized_hr": f0,
            "hr_baseline_deviation": f1,
            "normalized_spo2": np.nan,          # not measurable in this dataset
            "spo2_baseline_drop": np.nan,       # not measurable in this dataset
            "normalized_temp": f4,
            "temp_baseline_deviation": f5,
            "activity_level": f6,
            "sleep_duration_ratio": np.nan,     # not measurable in this dataset
            "sleep_quality": np.nan,            # not measurable in this dataset
            "ambient_temp": np.nan,             # not measurable in this dataset
            "humidity": np.nan,                 # not measurable in this dataset
            "aqi": np.nan,                      # not measurable in this dataset
            "heat_index": np.nan,               # not measurable in this dataset
            "heat_exposure_duration": np.nan,   # not measurable in this dataset
            "hrv_rmssd": f14,
            "hr_trend_slope": f15,
        })

    if not rows:
        return None
    return pd.DataFrame(rows)


def main():
    subject_dirs = sorted(
        d for d in glob.glob(os.path.join(PPG_DALIA_DIR, "S*"))
        if os.path.isdir(d)
    )
    subject_ids = [os.path.basename(d) for d in subject_dirs]

    all_dfs = []
    for sid in subject_ids:
        result = parse_one_subject(sid)
        if result is not None:
            all_dfs.append(result)
            print(f"  {sid}: {len(result)} windows")
        else:
            print(f"  WARNING: {sid} produced no usable windows, skipped")

    combined = pd.concat(all_dfs, ignore_index=True)
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    out_path = os.path.join(PROCESSED_DIR, "ppg_dalia_features.csv")
    combined.to_csv(out_path, index=False)

    print(f"\nParsed {len(subject_ids)} subjects -> {len(combined)} rows")
    print(f"Written to {out_path}")
    print(combined[["normalized_hr", "hr_baseline_deviation", "normalized_temp",
                     "activity_level", "hrv_rmssd", "hr_trend_slope"]].describe())


if __name__ == "__main__":
    main()