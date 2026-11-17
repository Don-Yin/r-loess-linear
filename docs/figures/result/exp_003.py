"""Each source reduction against R, in the timing case with one predictor and N = 45,000."""
from __future__ import annotations

from python_plotting_convention import FULL_TEXT_WIDTH_CM  # pyright: ignore[reportMissingImports]
from result_data import (
    DROPPED_PURPLE,
    KEPT_GREEN,
    build_point,
    headline_figure,
    headline_row,
    read_csv,
    source_record,
)

TABLES = "experiments/exp_003_reductions/.results/tables"
REDUCTIONS = f"{TABLES}/reductions.csv"

# The normal build of this variant has no allocation probe; its bytes come from its test build.

BYTES_FROM_TEST_BUILD = {"probes_out_of_production": "testing-timing.csv"}
NAMES = {"block_buffer_by_vertex_count": "block buffer", "single_plan_path": "single plan path"}


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    variants = read_csv(REDUCTIONS)
    if {row["verdict"] for row in variants} != {"kept", "dropped"}:
        raise ValueError("reductions.csv verdicts are not kept and dropped")
    kept = sum(row["verdict"] == "kept" for row in variants)
    builds, paths, plotted = [], [], {}
    for row in variants:
        name = row["name"]
        time_path = f"{TABLES}/{name}-timing.csv"
        bytes_path = f"{TABLES}/{name}-{BYTES_FROM_TEST_BUILD.get(name, 'timing.csv')}"
        time, size = headline_row(time_path, ("variant_s",)), headline_row(bytes_path, ("native_bytes",))
        is_kept = row["verdict"] == "kept"
        builds.append(build_point(f"{kept} kept" if is_kept else f"{len(variants) - kept} dropped", 3,
                                  KEPT_GREEN if is_kept else DROPPED_PURPLE, time["variant_s"],
                                  size["native_bytes"], filled=is_kept, name=NAMES.get(name)))
        paths += sorted({time_path, bytes_path})
        plotted[name] = {"verdict": row["verdict"], "seconds": time["variant_s"], "bytes": size["native_bytes"]}
    fig, record = headline_figure(
        builds, [source_record(REDUCTIONS, ["name", "verdict"]),
                 *(source_record(path, ["variant_s", "native_bytes"]) for path in paths)],
        "memory and time of each independently tested reduction against R in one large timing case",
        target_width_cm=target_width_cm)
    return fig, {**record, "variants": plotted, "bytes_from_test_build": BYTES_FROM_TEST_BUILD}
