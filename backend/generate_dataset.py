"""Generate a labelled CSV dataset for later model training (stdlib only)."""

from __future__ import annotations

import argparse
import csv
import random
from pathlib import Path

LABELS = ("Normal", "Abnormal Vibration", "Overheating", "Overcurrent")
OUTPUT = Path(__file__).resolve().parent / "data" / "synthetic_sensor_readings.csv"


def generate_dataset(rows: int = 4000, output: Path = OUTPUT,
                     seed: int = 42) -> int:
    if rows < len(LABELS):
        raise ValueError(f"rows must be at least {len(LABELS)}")
    rng = random.Random(seed)
    output.parent.mkdir(parents=True, exist_ok=True)
    fields = ["vibration", "temperature", "current", "condition"]
    with output.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader()
        # Balance the classes so the training exercise has examples of each fault.
        for index in range(rows):
            label = LABELS[index % len(LABELS)]
            vibration, temperature, current = (rng.gauss(2.2, .48),
                                               rng.gauss(58, 4.5),
                                               rng.gauss(8.5, 1.0))
            if label == "Abnormal Vibration":
                vibration = rng.gauss(7.2, .85)
            elif label == "Overheating":
                temperature = rng.gauss(94, 5)
            elif label == "Overcurrent":
                current = rng.gauss(16, 1.6)
            writer.writerow({"vibration": round(max(0, vibration), 3),
                             "temperature": round(max(0, temperature), 2),
                             "current": round(max(0, current), 3),
                             "condition": label})
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rows", type=int, default=4000)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    count = generate_dataset(args.rows, args.output, args.seed)
    print(f"Generated {count} simulated rows: {args.output.resolve()}")


if __name__ == "__main__":
    main()
