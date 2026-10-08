#!/usr/bin/env bash
set -e

# Resolve the prana_ml/ root regardless of where this script is called from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "Working in: $ROOT_DIR"

mkdir -p data/raw/ppg_dalia data/raw/bidmc data/raw/mmash data/raw/wesad

echo "== PPG-DaLiA (UCI, CC BY 4.0, ~2.7 GB) =="
curl -L -o data/raw/ppg_dalia/ppg_dalia.zip \
  "https://archive.ics.uci.edu/static/public/495/ppg+dalia.zip"
unzip -q data/raw/ppg_dalia/ppg_dalia.zip -d data/raw/ppg_dalia/

echo "== BIDMC PPG and Respiration (PhysioNet, ODC-BY, ~208 MB) =="
curl -L -o data/raw/bidmc/bidmc.zip \
  "https://physionet.org/content/bidmc/get-zip/1.0.0/"
unzip -q data/raw/bidmc/bidmc.zip -d data/raw/bidmc/

echo "== MMASH (PhysioNet, ODbL, ~23 MB) =="
curl -L -o data/raw/mmash/MMASH.zip \
  "https://physionet.org/files/mmash/1.0.0/MMASH.zip?download"
unzip -q data/raw/mmash/MMASH.zip -d data/raw/mmash/

echo "Done with automated downloads."