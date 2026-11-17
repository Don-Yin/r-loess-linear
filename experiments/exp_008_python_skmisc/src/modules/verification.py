"""Verify bitwise equality within Python and quantify differences from R."""

from __future__ import annotations

import json
import logging
import statistics

import numpy as np

from ..utils.output import write_table
from ..utils.paths import RESULTS

logger = logging.getLogger(__name__)
QUANTITIES = ("training_fit", "fit", "se", "residual_scale", "df")


def comparison(left: np.ndarray, right: np.ndarray, **keys) -> dict:
    """Compare binary64 payloads exactly, also retaining a numeric error scale."""
    equal = left.shape == right.shape and left.tobytes() == right.tobytes()
    return keys | {"bitwise_equal": equal, "max_abs_error": float(np.max(np.abs(left - right)))}


def summarize(records: list[dict], sizes: list[int], rounds: int) -> None:
    """Require all within-build comparisons to pass before writing final summaries."""
    measurements, checks, r_checks = [], [], []
    loaded = {}
    for record in records:
        build, n, rep = record["build"], record["n"], record["replicate"]
        label = f"{build}-n{n}-r{rep}"
        if record["status"] == "ok":
            data = json.loads((RESULTS / "json" / f"{label}.json").read_text())
            measurements.append(record | data)
            with np.load(RESULTS / "arrays" / f"{label}.npz") as arrays:
                loaded[(build, n, rep)] = {key: arrays[key].copy() for key in QUANTITIES}
        else:
            measurements.append(record | {"prediction_seconds": "", "prediction_user_seconds": "", "peak_rss_bytes": "", "vertices": "", "geometry_workspace_bytes": "", "coefficient_bytes": "", "workspace_bytes": "", "inverse_bytes": "", "influence_matrix_bytes": "", "native_bytes": "", "observed_native_bytes": "", "trace_verified": ""})
    for n in sizes:
        meta = json.loads((RESULTS / "json" / f"r-n{n}.json").read_text())
        r_values = np.fromfile(RESULTS / "data" / f"r-reference-{n}.bin", dtype="<f8")
        r_arrays = {"training_fit": r_values[:n], "fit": r_values[n:n + 80], "se": r_values[n + 80:n + 160]}
        for build in ("unpatched", "cache", "actual"):
            for rep in range(rounds):
                key = (build, n, rep)
                if key not in loaded:
                    continue
                for quantity in QUANTITIES:
                    value = loaded[key][quantity]
                    if rep:
                        checks.append(comparison(loaded[(build, n, 0)][quantity], value, pair=f"{build}-repeat", n=n, replicate=rep, quantity=quantity))
                    if build != "unpatched" and ("unpatched", n, rep) in loaded:
                        checks.append(comparison(loaded[("unpatched", n, rep)][quantity], value, pair=f"unpatched-vs-{build}", n=n, replicate=rep, quantity=quantity))
                    if build == "actual" and ("cache", n, rep) in loaded:
                        checks.append(comparison(loaded[("cache", n, rep)][quantity], value, pair="cache-vs-actual", n=n, replicate=rep, quantity=quantity))
                    if quantity in r_arrays and (quantity != "se" or meta["status"] == "ok"):
                        r_checks.append(comparison(r_arrays[quantity], value, build=build, n=n, replicate=rep, quantity=quantity, r_status=meta["status"]))
    write_table("measurements.csv", measurements)
    write_table("checks.csv", checks)
    write_table("r-comparisons.csv", r_checks)
    failed = [row for row in checks if not row["bitwise_equal"]]
    if failed:
        raise ValueError(f"bitwise comparisons failed: {failed!r}; see .results/tables/checks.csv")
    excessive = [row for row in r_checks if row["max_abs_error"] > 1e-10]
    if excessive:
        raise ValueError(f"R comparisons exceed absolute tolerance 1e-10: {excessive!r}")
    summary = []
    for n in sizes:
        for build in ("unpatched", "cache", "actual"):
            rows = [row for row in measurements if row["n"] == n and row["build"] == build]
            row = {"build": build, "n": n, "replicates": len(rows), "status": rows[0]["status"]}
            for key in ("prediction_seconds", "prediction_user_seconds", "peak_rss_bytes", "vertices", "geometry_workspace_bytes", "coefficient_bytes", "workspace_bytes", "inverse_bytes", "influence_matrix_bytes", "native_bytes", "observed_native_bytes"):
                row[key] = statistics.median(r[key] for r in rows) if row["status"] == "ok" else ""
            summary.append(row)
    write_table("summary.csv", summary)
    results = {"checks": {"cases": len(checks), "bitwise_equal": sum(row["bitwise_equal"] for row in checks)}, "r_checks": {"cases": len(r_checks), "bitwise_equal": sum(row["bitwise_equal"] for row in r_checks), "max_abs_error": max(row["max_abs_error"] for row in r_checks)}, "sizes": sizes, "rounds": rounds, "expected_sigsegv_processes": sum(row["returncode"] == -11 for row in records)}
    (RESULTS / "json" / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
    logger.info("all %d bitwise checks passed; R max absolute error %.6g", len(checks), results["r_checks"]["max_abs_error"])
