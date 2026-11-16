"""Worst case: the zero-radius input with N = 8,192 under forced retention caps, against R."""
from __future__ import annotations

from python_plotting_convention import FULL_TEXT_WIDTH_CM  # pyright: ignore[reportMissingImports]
from result_data import (
    DEFAULT_BLUE,
    absolute_figure,
    build_point,
    r_on_tied,
    read_csv,
    source_record,
)

TABLES = "experiments/exp_002_worst_case/.results/tables"
CASE = "zero-radius-1-8192-128"
CAPS = {0: "cap 0", 65536: "64 KiB", 67108864: "64 MiB"}
DEFAULT_CAP = 67108864
SMALL_ORANGE = "#ee7733"
COLUMNS = ["id", "public_error", "baseline_s", "baseline_native_bytes"]


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    rows, sources = {}, []
    for cap in CAPS:
        path = f"{TABLES}/worst-cap-{cap}.csv"
        found = [r for r in read_csv(path, numeric_columns=COLUMNS[2:]) if r["id"] == f"{CASE}-{cap}"]
        if len(found) != 1 or found[0]["public_error"] != "TRUE":
            raise ValueError(f"{path}: expected one {CASE} row where R stops with an error")
        rows[cap] = found[0]
        sources.append(source_record(path, COLUMNS))
    builds = {cap: build_point("prototype, default cap 64 MiB" if cap == DEFAULT_CAP else "prototype, forced small cap",
                               2, DEFAULT_BLUE if cap == DEFAULT_CAP else SMALL_ORANGE, row["baseline_s"],
                               row["baseline_native_bytes"], name=None if cap == 65536 else
                               ("cap 0 and 64 KiB" if cap == 0 else "64 MiB"))
              for cap, row in rows.items()}
    r, r_source = r_on_tied(CASE)
    zoom = (max(p["bytes"] for p in builds.values()) * 1.35, max(p["seconds"] for p in builds.values()) * 1.15)
    fig, kind = absolute_figure([r, *builds.values()], zoom=zoom, links=[list(builds.values())],
                                target_width_cm=target_width_cm)
    return fig, {
        **kind,
        "scientific_job": "memory against time for one worst-case input under three retention caps, against R",
        "input": "one predictor, N = 8,192, M = 128, many tied x values (zero-radius vertices)",
        "sources": [*sources, r_source],
        "timing": "direct native standard-error calls, also for R; R's public predict stops before them",
    }
