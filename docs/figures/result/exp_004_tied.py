"""Worst case: the prototype's time on the 15 tied inputs at the default cap, against R."""
from __future__ import annotations

from python_plotting_convention import (  # pyright: ignore[reportMissingImports]
    FULL_TEXT_WIDTH_CM,
)
from result_data import DEFAULT_BLUE
from tied_cases import TIME, tied_cases_figure

FINDINGS = "experiments/exp_004_worst_case/.results/tables/default-cap-findings.csv"


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    time = {**TIME, "column": "baseline_s"}
    fig, kind = tied_cases_figure(FINDINGS, ("prototype", 4, DEFAULT_BLUE), [time, {**time, "below": 1.5}],
                                  target_width_cm=target_width_cm)
    return fig, {**kind, "scientific_job": "which tied inputs the prototype is slow on, against R",
                 "timing": "user CPU of the native standard-error routine; R from r-tied.R, a separate run"}
