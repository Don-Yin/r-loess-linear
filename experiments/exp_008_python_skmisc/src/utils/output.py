"""Write experiment-owned reader-facing tables."""

import csv

from .paths import RESULTS


def write_table(name: str, rows: list[dict]) -> None:
    """Replace selected sizes while retaining measurements from other sizes."""
    path = RESULTS / "tables" / name
    if "n" in rows[0] and path.exists():
        sizes = {str(row["n"]) for row in rows}
        with path.open(newline="") as stream:
            rows = [row for row in csv.DictReader(stream) if row["n"] not in sizes] + rows
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(dict.fromkeys(key for row in rows for key in row)))
        writer.writeheader()
        writer.writerows(rows)
