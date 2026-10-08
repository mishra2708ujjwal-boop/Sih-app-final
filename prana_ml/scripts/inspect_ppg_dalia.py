"""What we're changing: A read-only inspector — loads one subject's pickle and prints its structure (keys, nested keys, array shapes/dtypes) without processing or writing anything. This tells us exactly how to write parse_ppg_dalia.py correctly on the first try."""
import pickle
import numpy as np
import os

PPG_DALIA_DIR = os.path.join("..", "data", "raw", "ppg_dalia", "PPG_FieldStudy")
SUBJECT = "S1"


def describe(obj, prefix="", max_depth=3, depth=0):
    """Recursively print the shape/type of a nested dict without dumping
    raw values, so we can see the structure without a wall of numbers."""
    if depth > max_depth:
        print(f"{prefix}... (max depth reached)")
        return

    if isinstance(obj, dict):
        for k, v in obj.items():
            print(f"{prefix}['{k}'] -> {type(v).__name__}", end="")
            if isinstance(v, np.ndarray):
                print(f"  shape={v.shape} dtype={v.dtype}")
            elif isinstance(v, (list, tuple)):
                print(f"  len={len(v)}")
            else:
                print()
            if isinstance(v, dict):
                describe(v, prefix=prefix + f"['{k}']", max_depth=max_depth, depth=depth + 1)
    else:
        print(f"{prefix} -> {type(obj).__name__}")


def main():
    path = os.path.join(PPG_DALIA_DIR, SUBJECT, f"{SUBJECT}.pkl")
    print(f"Loading: {path}")
    print(f"File exists: {os.path.exists(path)}")

    with open(path, "rb") as f:
        data = pickle.load(f, encoding="latin1")

    print(f"\nTop-level type: {type(data).__name__}")
    print("Structure:")
    describe(data)


if __name__ == "__main__":
    main()
    