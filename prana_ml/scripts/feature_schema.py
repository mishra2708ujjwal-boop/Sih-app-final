"""
prana_ml/scripts/feature_schema.py

Single source of truth for the 16-feature contract frozen in Phase 1.
Every dataset parser MUST write its output columns in this exact order,
using these exact names. Nothing here should be edited without also
updating the Dart FeatureProcessor and re-freezing both together.
"""

FEATURE_NAMES = [
    "normalized_hr",            # 0
    "hr_baseline_deviation",    # 1
    "normalized_spo2",          # 2
    "spo2_baseline_drop",       # 3
    "normalized_body_temp",     # 4
    "body_temp_deviation",      # 5
    "activity_level",           # 6
    "sleep_duration_ratio",     # 7
    "sleep_quality",            # 8
    "ambient_temp",             # 9
    "humidity",                 # 10
    "aqi",                      # 11
    "heat_index",                # 12
    "heat_exposure_duration",   # 13
    "hrv_rmssd",                 # 14
    "hr_trend_slope",           # 15
]

assert len(FEATURE_NAMES) == 16, "Feature contract must stay at exactly 16 features"

# Columns every parser must always emit, in addition to whichever
# FEATURE_NAMES it can actually populate (the rest are left as NaN
# and must NOT be silently filled with fabricated values).
META_COLUMNS = [
    "source_dataset",   # e.g. "ppg_dalia", "bidmc", "mmash"
    "subject_id",       # dataset-native subject identifier, kept as string
    "window_start_s",   # seconds from start of that subject's recording
]

OUTPUT_COLUMNS = META_COLUMNS + FEATURE_NAMES