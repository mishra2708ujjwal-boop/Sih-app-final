import glob
import os
import pickle

import numpy as np
import pandas as pd

PPG_DALIA_DIR = os.path.join("..", "data", "raw", "ppg_dalia", "PPG_FieldStudy")
CHEST_HZ = 700
WRIST_4HZ = 4
SHIFT_SEC = 2
TREND_MAX_SAMPLES = 8


def raw_slopes_for_subject(subject_id):
    path = os.path.join(PPG_DALIA_DIR, subject_id, f"{subject_id}.pkl")
    with open(path, "rb") as f:
        data = pickle.load(f, encoding="latin1")
    hr = np.asarray(data["label"]).flatten()

    raws = []
    for i in range(3, len(hr)):
        window = hr[max(0, i - TREND_MAX_SAMPLES + 1):i + 1]
        xs = np.arange(len(window)) * (SHIFT_SEC / 60.0)  # minutes
        ys = window
        x_mean, y_mean = xs.mean(), ys.mean()
        denom = np.sum((xs - x_mean) ** 2)
        if denom == 0:
            continue
        slope_bpm_per_min = np.sum((xs - x_mean) * (ys - y_mean)) / denom
        raws.append(slope_bpm_per_min)
    return raws


def main():
    subject_dirs = sorted(d for d in glob.glob(os.path.join(PPG_DALIA_DIR, "S*")) if os.path.isdir(d))
    all_raw = []
    for d in subject_dirs:
        all_raw.extend(raw_slopes_for_subject(os.path.basename(d)))

    arr = np.array(all_raw)
    print(f"Total raw slope samples: {len(arr)}")
    print(pd.Series(arr).describe())
    print()
    for thresh in [5, 10, 15, 20, 30]:
        pct = 100 * np.mean(np.abs(arr) >= thresh)
        print(f"% with |raw slope| >= {thresh} BPM/min (i.e. would clamp at normalization={thresh/2.0}): {pct:.1f}%")


if __name__ == "__main__":
    main()