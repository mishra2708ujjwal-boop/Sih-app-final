"""
prana_ml/scripts/parse_mmash.py

Parses the MMASH dataset into the frozen 16-feature schema. Populates
features 0, 1, 6, 7, 8, 14, 15 -- HR, HR baseline deviation, activity
level, sleep duration ratio, sleep quality, HRV RMSSD, and HR trend
slope. Everything else (SpO2, body temp, environment) is left as NaN --
MMASH has no sensors for those, so nothing is fabricated to fill them.

Per-subject HR baseline is that subject's own median instantaneous HR
across their 24h recording (same personal-baseline approach used for
BIDMC), not a population constant.

Activity level: MMASH logs 12 specific activity categories in
Activity.csv. FeatureSchema only has 4 buckets (rest/low/moderate/high).
The mapping below re-buckets MMASH's real logged categories by physical
intensity -- it does not invent activity data. Review ACTIVITY_CODE_MAP
below if you'd bucket any category differently.

Sleep: MMASH logs one or more sleep sessions per subject in sleep.csv.
The session with the largest Total Sleep Time (TST) is treated as that
subject's main sleep event, and its duration/efficiency are broadcast
as a constant value across all of that subject's windows (MMASH doesn't
give a nightly SleepReading like the app does -- it gives one real
sleep session per subject, which is what's actually available).
"""

import glob
import os
import re
import numpy as np
import pandas as pd

from feature_constants import (
    HR_MIN_BPM, HR_RANGE_BPM, HR_DEV_CLAMP_MIN, HR_DEV_CLAMP_MAX,
    TREND_SLOPE_CLAMP_MIN, TREND_SLOPE_CLAMP_MAX,
    TREND_NORMALIZATION_BPM_PER_MIN,
    SLEEP_GOAL_MINUTES, SLEEP_DURATION_CLAMP_MAX,
    ACTIVITY_REST, ACTIVITY_LOW, ACTIVITY_MODERATE_DEFAULT, ACTIVITY_HIGH,
    HRV_MAX_MS,
)
from baseline_utils import clamp, rolling_trend_slope
from feature_schema import OUTPUT_COLUMNS, FEATURE_NAMES

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)

MMASH_DIR = os.path.join(ROOT_DIR, "data", "raw", "mmash", "DataPaper")
PROCESSED_DIR = os.path.join(ROOT_DIR, "data", "processed")

WINDOW_SECONDS = 60
MIN_BEATS_PER_WINDOW = 2  # need at least 2 beats for an RMSSD diff

# MMASH Activity.csv codes -> FeatureSchema activity buckets.
# 1 sleeping, 2 laying down       -> rest
# 3 sitting, 7 eating, 8 small screen, 9 large screen,
#   10 caffeinated drink, 11 smoking, 12 alcohol   -> low (seated/still)
# 4 light movement (slow walk, chores)             -> low
# 5 medium (fast walk, bike)                       -> moderate
# 6 heavy (gym, running)                            -> high
ACTIVITY_CODE_MAP = {
    1: ACTIVITY_REST,
    2: ACTIVITY_REST,
    3: ACTIVITY_LOW,
    4: ACTIVITY_LOW,
    5: ACTIVITY_MODERATE_DEFAULT,
    6: ACTIVITY_HIGH,
    7: ACTIVITY_LOW,
    8: ACTIVITY_LOW,
    9: ACTIVITY_LOW,
    10: ACTIVITY_LOW,
    11: ACTIVITY_LOW,
    12: ACTIVITY_LOW,
}


def hms_to_seconds(t_str, day):
    """Convert 'HH:MM:SS' or 'HH:MM' plus a 1/2 day marker into elapsed
    seconds from the start of day 1, so ordering and window bucketing
    are consistent even across the day-1/day-2 boundary."""
    parts = t_str.strip().split(":")
    h = int(parts[0])
    m = int(parts[1])
    s = int(parts[2]) if len(parts) > 2 else 0
    return (int(day) - 1) * 86400 + h * 3600 + m * 60 + s


def load_rr(user_dir):
    path = os.path.join(user_dir, "RR.csv")
    if not os.path.exists(path):
        return None
    df = pd.read_csv(path)
    df = df.dropna(subset=["ibi_s", "day", "time"])
    df["time_s"] = df.apply(lambda r: hms_to_seconds(r["time"], r["day"]), axis=1)
    df = df.sort_values("time_s").reset_index(drop=True)
    df["inst_hr"] = 60.0 / df["ibi_s"]
    # Drop physiologically implausible beats (sensor glitches, not real HR)
    df = df[(df["inst_hr"] >= 30) & (df["inst_hr"] <= 220)]
    return df


def load_activity(user_dir):
    path = os.path.join(user_dir, "Activity.csv")
    if not os.path.exists(path):
        return None
    df = pd.read_csv(path)
    df = df.dropna(subset=["Activity", "Start", "End", "Day"])
    df["start_s"] = df.apply(lambda r: hms_to_seconds(r["Start"], r["Day"]), axis=1)
    df["end_s"] = df.apply(lambda r: hms_to_seconds(r["End"], r["Day"]), axis=1)
    return df


def activity_level_at(activity_df, window_start_s):
    if activity_df is None:
        return ACTIVITY_MODERATE_DEFAULT
    match = activity_df[
        (activity_df["start_s"] <= window_start_s) & (activity_df["end_s"] >= window_start_s)
    ]
    if len(match) == 0:
        return ACTIVITY_MODERATE_DEFAULT
    code = int(match.iloc[0]["Activity"])
    return ACTIVITY_CODE_MAP.get(code, ACTIVITY_MODERATE_DEFAULT)


def load_sleep(user_dir):
    path = os.path.join(user_dir, "sleep.csv")
    if not os.path.exists(path):
        return None, None
    df = pd.read_csv(path)
    df = df.dropna(subset=["Total Sleep Time (TST)", "Efficiency"])
    if len(df) == 0:
        return None, None
    main = df.loc[df["Total Sleep Time (TST)"].idxmax()]
    tst_minutes = float(main["Total Sleep Time (TST)"])
    efficiency_pct = float(main["Efficiency"])
    return tst_minutes, efficiency_pct


def parse_one_subject(user_dir, subject_id):
    rr = load_rr(user_dir)
    if rr is None or len(rr) == 0:
        return None

    activity_df = load_activity(user_dir)
    tst_minutes, efficiency_pct = load_sleep(user_dir)

    if tst_minutes is not None:
        f7_sleep_duration = clamp(tst_minutes / SLEEP_GOAL_MINUTES, 0.0, SLEEP_DURATION_CLAMP_MAX)
        f8_sleep_quality = clamp(efficiency_pct / 100.0, 0.0, 1.0)
    else:
        f7_sleep_duration = np.nan
        f8_sleep_quality = np.nan

    baseline_hr_mid = rr["inst_hr"].median()

    rr["window_idx"] = (rr["time_s"] // WINDOW_SECONDS).astype(int)
    window_ids = sorted(rr["window_idx"].unique())

    window_starts, window_hrs, window_rmssds = [], [], []
    for w in window_ids:
        chunk = rr[rr["window_idx"] == w]
        if len(chunk) < MIN_BEATS_PER_WINDOW:
            continue
        window_starts.append(int(chunk["time_s"].min()))
        window_hrs.append(chunk["inst_hr"].mean())
        ibi_ms = chunk["ibi_s"].to_numpy() * 1000.0
        diffs = np.diff(ibi_ms)
        rmssd = float(np.sqrt(np.mean(diffs ** 2))) if len(diffs) >= 1 else np.nan
        window_rmssds.append(rmssd)

    if len(window_starts) == 0:
        return None

    slopes = rolling_trend_slope(window_starts, window_hrs)

    rows = []
    for i in range(len(window_starts)):
        ws = window_starts[i]
        hr = window_hrs[i]
        rmssd = window_rmssds[i]

        f0 = clamp((hr - HR_MIN_BPM) / HR_RANGE_BPM, 0.0, 1.0)
        f1 = clamp((hr - baseline_hr_mid) / baseline_hr_mid, HR_DEV_CLAMP_MIN, HR_DEV_CLAMP_MAX)
        f6 = activity_level_at(activity_df, ws)
        f14 = clamp(rmssd / HRV_MAX_MS, 0.0, 1.0) if not np.isnan(rmssd) else np.nan

        slope = slopes[i]
        f15 = (
            clamp(slope / TREND_NORMALIZATION_BPM_PER_MIN, TREND_SLOPE_CLAMP_MIN, TREND_SLOPE_CLAMP_MAX)
            if slope is not None else np.nan
        )

        feature_values = {name: np.nan for name in FEATURE_NAMES}
        feature_values.update({
            "normalized_hr": f0,
            "hr_baseline_deviation": f1,
            "activity_level": f6,
            "sleep_duration_ratio": f7_sleep_duration,
            "sleep_quality": f8_sleep_quality,
            "hrv_rmssd": f14,
            "hr_trend_slope": f15,
        })

        row = {"source_dataset": "mmash", "subject_id": subject_id, "window_start_s": ws}
        row.update(feature_values)
        rows.append(row)

    return pd.DataFrame(rows, columns=OUTPUT_COLUMNS)


def main():
    user_dirs = sorted(
        glob.glob(os.path.join(MMASH_DIR, "user_*")),
        key=lambda p: int(re.search(r"user_(\d+)", p).group(1)),
    )
    if not user_dirs:
        raise SystemExit(f"No user_* folders found under {MMASH_DIR} -- check the path.")

    all_dfs = []
    for user_dir in user_dirs:
        subject_id = re.search(r"user_(\d+)", user_dir).group(1)
        result = parse_one_subject(user_dir, subject_id)
        if result is not None:
            all_dfs.append(result)
        else:
            print(f"  WARNING: user_{subject_id} produced no usable windows, skipped")

    combined = pd.concat(all_dfs, ignore_index=True)
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    out_path = os.path.join(PROCESSED_DIR, "mmash_features.csv")
    combined.to_csv(out_path, index=False)

    print(f"Parsed {len(user_dirs)} subjects -> {len(combined)} rows")
    print(f"Written to {out_path}")
    print(combined[["normalized_hr", "hr_baseline_deviation", "activity_level",
                     "sleep_duration_ratio", "sleep_quality", "hrv_rmssd",
                     "hr_trend_slope"]].describe())


if __name__ == "__main__":
    main()