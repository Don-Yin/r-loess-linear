"""Build each source variant, run isolated workers, then verify and summarize."""

from __future__ import annotations

import logging
import os
import subprocess
import sys
from pathlib import Path

from ..utils.paths import EXPERIMENT_DIR, RESULTS
from .builds import build_all
from .memory import FIRST_INVALID_N
from .sources import prepare_sources
from .verification import summarize

logger = logging.getLogger(__name__)
BUILDS = ("unpatched", "cache", "actual")


def command(args: list[str], log: Path, *, env: dict[str, str] | None = None) -> int:
    """Save both worker streams and return the real process exit status."""
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w") as stream:
        result = subprocess.run(args, cwd=EXPERIMENT_DIR, env=env, stdout=stream, stderr=subprocess.STDOUT)
    return result.returncode


def run(sizes: list[int], rounds: int, *, profile: bool) -> None:
    """Run independent processes in alternating build order at each size."""
    if rounds < 1 or not sizes or any(n < 32 for n in sizes) or len(set(sizes)) != len(sizes):
        raise ValueError(f"invalid sizes={sizes!r} or rounds={rounds!r}")
    prepare_sources()
    build_all(BUILDS)
    env = os.environ.copy()
    env.update(OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1", PYTHONDONTWRITEBYTECODE="1")
    records = []
    total = len(sizes) * (1 + len(BUILDS) * rounds)
    step = 0
    for n in sizes:
        step += 1
        logger.info("[%d/%d] R reference n=%d", step, total, n)
        rprofile = str(RESULTS / "profile" / f"r-n{n}.Rprof") if profile else ""
        status = command(["Rscript", str(EXPERIMENT_DIR / "src" / "modules" / "reference.R"), str(n), str(RESULTS), rprofile], RESULTS / "logs" / f"r-n{n}.log", env=env)
        if status:
            raise RuntimeError(f"R reference n={n} returned {status}; see .results/logs/r-n{n}.log")
        for rep in range(rounds):
            for build in BUILDS if rep % 2 == 0 else tuple(reversed(BUILDS)):
                step += 1
                label = f"{build}-n{n}-r{rep}"
                logger.info("[%d/%d] prediction %s", step, total, label)
                worker_env = env | {"DYLD_INSERT_LIBRARIES": str(EXPERIMENT_DIR / ".intermediates" / "trace-alloc.dylib")}
                args = [sys.executable, "-m", "src.modules.worker", build, str(n), str(rep)]
                if not profile:
                    args.append("--no-profile")
                status = command(args, RESULTS / "logs" / f"{label}.log", env=worker_env)
                expected_signal = build != "actual" and n >= FIRST_INVALID_N
                if status != (-11 if expected_signal else 0):
                    raise RuntimeError(f"worker {label} returned {status}, expected {'-11' if expected_signal else '0'}; see .results/logs/{label}.log")
                records.append({"build": build, "n": n, "replicate": rep, "returncode": status, "status": "sigsegv" if status == -11 else "ok"})
    summarize(records, sizes, rounds)
