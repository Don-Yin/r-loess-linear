"""Write experiment-owned reader-facing tables."""

import csv

from .paths import RESULTS


def write_table(name: str, rows: list[dict]) -> None:
    """Save rows with stable columns under the result table directory."""
    with (RESULTS / "tables" / name).open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
