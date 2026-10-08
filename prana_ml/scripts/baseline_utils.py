"""
prana_ml/scripts/baseline_utils.py
Shared helpers: personal-baseline derivation and HR trend-slope calculation,
matching the semantics of the Dart FeatureProcessor / HrTrendCalculator.
"""

import numpy as np
from feature_constants import TREND_MIN_SAMPLES, TREND_MAX_SAMPLES


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def least_squares_slope_bpm_per_min(times_s, values):
    """
    Least-squares slope of `values` vs `times_s`, returned in units/minute.
    Mirrors HrTrendCalculator.computeSlope's approach: a simple linear fit
    over the recent window, expressed as a per-minute rate.
    """
    if len(values) < TREND_MIN_SAMPLES:
        return None
    times_min = np.array(times_s) / 60.0
    vals = np.array(values)
    slope, _intercept = np.polyfit(times_min, vals, 1)
    return float(slope)


def rolling_trend_slope(window_times_s, window_values, max_samples=TREND_MAX_SAMPLES):
    """
    For each window index i, compute the slope using up to `max_samples`
    preceding windows (inclusive of i), or None if fewer than
    TREND_MIN_SAMPLES are available yet. Returns a list the same length
    as window_values.
    """
    out = []
    for i in range(len(window_values)):
        start = max(0, i - max_samples + 1)
        t_slice = window_times_s[start:i + 1]
        v_slice = window_values[start:i + 1]
        out.append(least_squares_slope_bpm_per_min(t_slice, v_slice))
    return out