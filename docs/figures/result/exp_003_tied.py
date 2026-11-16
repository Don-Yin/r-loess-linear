"""Package source: time and memory on the 15 tied inputs, against R."""
from __future__ import annotations

from python_plotting_convention import FULL_TEXT_WIDTH_CM  # pyright: ignore[reportMissingImports]
from result_data import DEFAULT_BLUE
from tied_cases import MEMORY, TIME, tied_cases_figure

COMPARISON = "experiments/exp_003_package_source/.results/tables/tied-comparison.csv"


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    fig, kind = tied_cases_figure(
        COMPARISON, ("package source", 3, DEFAULT_BLUE),
        [{**TIME, "column": "priority_baseline_s"}, {**MEMORY, "column": "priority_baseline_native_bytes"}],
        target_width_cm=target_width_cm)
    return fig, {**kind, "scientific_job": "time and memory of the package source on every tied input, against R",
                 "timing": "user CPU of the native standard-error routine; R from r-tied.R, a separate run",
                 "memory": "native bytes requested, from the copy built with the test probes; R's is its workspace"}
