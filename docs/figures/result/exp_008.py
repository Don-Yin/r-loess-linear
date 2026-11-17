"""Python skmisc builds in the one-predictor, N = 45,000 prediction case."""
from __future__ import annotations

from matplotlib.image import imread
from python_plotting_convention import FULL_TEXT_WIDTH_CM  # pyright: ignore[reportMissingImports]
from result_data import (
    BEFORE_RED,
    DEFAULT_BLUE,
    HEADLINE_TEXT,
    ROOT,
    absolute_figure,
    build_point,
    logo_point,
    read_csv,
    source_record,
)

SUMMARY = "experiments/exp_008_python_skmisc/.results/tables/summary.csv"
COLUMNS = ("prediction_user_seconds", "native_bytes")
PYTHON_LOGO = "docs/assets/python-logo.png"
LOGO_SOURCE = "https://s3.dualstack.us-east-2.amazonaws.com/pythondotorg-assets/media/community/logos/python-logo-only.png"
LOGO_PERMISSION = "https://www.python.org/psf/trademarks/#uses-that-never-require-approval"


def build_figure(*, target_width_cm: float = FULL_TEXT_WIDTH_CM):
    rows = [row for row in read_csv(SUMMARY) if row["n"] == "45000"]
    measured = {row["build"]: row for row in rows}
    if len(rows) != 3 or set(measured) != {"unpatched", "cache", "actual"}:
        raise ValueError(f"{SUMMARY}: expected the three skmisc builds at N = 45,000")
    for row in rows:
        if row["status"] != "ok" or row["replicates"] != "3":
            raise ValueError(f"{SUMMARY}: incomplete measurements for {row['build']} at N = 45,000")
        for column in COLUMNS:
            try:
                row[column] = float(row[column])
            except ValueError as error:
                raise ValueError(f"{SUMMARY}: invalid {column}={row[column]!r} for {row['build']}") from error
    original = logo_point("skmisc (unpatched)", imread(ROOT / PYTHON_LOGO),
                          *(measured["unpatched"][column] for column in COLUMNS))
    builds = [build_point(label, 8, colour, *(measured[build][column] for column in COLUMNS), filled=filled)
              for build, label, colour, filled in (
                  ("cache", "cache only", BEFORE_RED, False),
                  ("actual", "cache + actual vertices", DEFAULT_BLUE, True))]
    zoom = (max(point["bytes"] for point in builds) * 1.08, max(point["seconds"] for point in builds) * 1.5)
    fig, record = absolute_figure([original, *builds], zoom=zoom, zoom_heading="fast range, enlarged",
                                 target_width_cm=target_width_cm)
    return fig, {**record, "scientific_job": "compare unpatched skmisc with the cache and actual-vertex ports",
                 "input": HEADLINE_TEXT,
                 "sources": [source_record(SUMMARY, ["build", "n", "status", "replicates", *COLUMNS]),
                             {**source_record(PYTHON_LOGO, []), "source_url": LOGO_SOURCE,
                              "permission": LOGO_PERMISSION, "owner": "Python Software Foundation"}],
                 "timing": "median user CPU of three public predict(..., stderror=True) calls per build",
                 "memory_definition": "native bytes requested for geometry, coefficients and inverse cache; "
                                      "excludes the dense influence matrix, Python allocations and peak RSS"}
