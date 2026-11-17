"""Compare pinned scikit-misc builds on Toby's interpolation and standard errors."""

from __future__ import annotations

import argparse
import logging

from src.modules.orchestration import run
from src.utils.paths import RESULTS
from src.utils.profiling import profiled, run_resources


def parse_args() -> argparse.Namespace:
    """Parse the measurement sizes and the default-on profiling switch."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-profile", action="store_true")
    parser.add_argument("--resources", action="store_true")
    parser.add_argument("--sizes", type=int, nargs="+", default=[128, 512, 1000, 2048, 8192, 16384, 32768, 45000, 46336, 46337, 100000])
    parser.add_argument("--rounds", type=int, default=3)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    with (
        run_resources(enabled=args.resources),
        profiled(None if args.no_profile else RESULTS / "profile" / "run.html"),
    ):
        run(args.sizes, args.rounds, profile=not args.no_profile)
