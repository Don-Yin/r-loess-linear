"""Package source against R, in the timing case with one predictor and N = 45,000."""
from __future__ import annotations

from python_plotting_convention import FULL_TEXT_WIDTH_CM  # pyright: ignore[reportMissingImports]
from result_data import (
    DEFAULT_BLUE,
    build_point,
    headline_figure,
    headline_row,
    probed_headline_bytes,
    source_record,
)

TIMING = "experiments/exp_005_package_source/.results/tables/timing.csv"


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    seconds = headline_row(TIMING, ("variant_s",))["variant_s"]
    size, size_source = probed_headline_bytes("before_native_bytes")
    package = build_point("package source", 5, DEFAULT_BLUE, seconds, size)
    return headline_figure([package], [source_record(TIMING, ["variant_s"]), size_source],
                           "package source memory and time against R in one large timing case",
                           target_width_cm=target_width_cm)
