"""One fresh-process fit and standard-error prediction from a private wheel."""

from __future__ import annotations

import argparse
import importlib
import json
import logging
import os
import resource
import sys
import time
from pathlib import Path

import numpy as np

from ..utils.paths import RESULTS
from ..utils.profiling import profiled
from .memory import requested_bytes
from .sources import INTERMEDIATES

logger = logging.getLogger(__name__)


def measure(build: str, n: int, replicate: int, *, profile: bool) -> None:
    """Profile real fitting/prediction, timing only the public prediction call."""
    if n < 32 or replicate < 0:
        raise ValueError(f"invalid n={n} or replicate={replicate}")
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    prefix = INTERMEDIATES / "installs" / build
    sys.path.insert(0, str(prefix))
    module = importlib.import_module("skmisc.loess")
    if module.__file__ is None or not Path(module.__file__).is_relative_to(prefix):
        raise ValueError(f"loaded {module.__file__}, not the private {build} wheel")
    values = np.fromfile(RESULTS / "data" / f"input-{n}.bin", dtype="<f8")
    if len(values) != 2 * n + 80:
        raise ValueError(f"input-{n}.bin has {len(values)} binary64 values, expected {2 * n + 80}")
    x, y, query = values[:n], values[n:2 * n], values[2 * n:]
    label = f"{build}-n{n}-r{replicate}"
    logger.info("fitting %s with trace_hat=exact, degree=2, span=0.5, cell=0.2", label)
    with profiled(RESULTS / "profile" / f"{label}-fit.html" if profile else None):
        model = module.loess(x, y, span=0.5, degree=2, cell=0.2, trace_hat="exact", surface="interpolate", statistics="approximate", family="gaussian")
        model.fit()
    trace = RESULTS / "tables" / "allocations" / f"{label}.csv"
    trace.parent.mkdir(parents=True, exist_ok=True)
    trace.write_text("kind,count,item_bytes,requested_bytes,success\n")
    logger.info("predicting %s at %d points", label, len(query))
    with profiled(RESULTS / "profile" / f"{label}.html" if profile else None):
        os.environ["LOESS_ALLOC_TRACE"] = str(trace)
        try:
            user0 = resource.getrusage(resource.RUSAGE_SELF).ru_utime
            start = time.perf_counter()
            prediction = model.predict(query, stderror=True)
            elapsed = time.perf_counter() - start
            usage = resource.getrusage(resource.RUSAGE_SELF)
            user_seconds = usage.ru_utime - user0
        finally:
            os.environ.pop("LOESS_ALLOC_TRACE", None)
    arrays = {"training_fit": np.asarray(model.outputs.fitted_values), "fit": np.asarray(prediction.values), "se": np.asarray(prediction.stderr), "residual_scale": np.array([prediction.residual_scale]), "df": np.array([prediction.df])}
    if any(not np.all(np.isfinite(array)) for array in arrays.values()):
        raise ValueError(f"nonfinite results from {label}")
    np.savez(RESULTS / "arrays" / f"{label}.npz", allow_pickle=False, **arrays)
    meta = json.loads((RESULTS / "json" / f"r-n{n}.json").read_text())
    memory = requested_bytes(build, n, meta["vertices"], trace)
    measurement = {"prediction_seconds": elapsed, "prediction_user_seconds": user_seconds, "peak_rss_bytes": int(usage.ru_maxrss if sys.platform == "darwin" else usage.ru_maxrss * 1024)} | memory
    (RESULTS / "json" / f"{label}.json").write_text(json.dumps(measurement, indent=2) + "\n")
    logger.info("finished %s seconds=%.6f native_bytes=%d", label, elapsed, memory["native_bytes"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build", choices=("unpatched", "cache", "actual"))
    parser.add_argument("n", type=int)
    parser.add_argument("replicate", type=int)
    parser.add_argument("--no-profile", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    measure(args.build, args.n, args.replicate, profile=not args.no_profile)
