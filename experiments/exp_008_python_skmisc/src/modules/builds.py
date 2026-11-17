"""Build wheels without installing scikit-misc into the shared interpreter."""

from __future__ import annotations

import importlib.metadata
import json
import logging
import os
import platform
import shutil
import subprocess
import sys
import zipfile

from ..utils.paths import EXPERIMENT_DIR, RESULTS
from .sources import INTERMEDIATES

logger = logging.getLogger(__name__)


def build_all(builds: tuple[str, ...]) -> None:
    """Compile identical-source variants and unpack each into its private prefix."""
    env = os.environ.copy()
    for key, name in (("TMPDIR", "tmp"), ("PIP_CACHE_DIR", "pip-cache"), ("XDG_CACHE_HOME", "cache")):
        path = INTERMEDIATES / name
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    env.update(CC="clang", FC="gfortran", PYTHONDONTWRITEBYTECODE="1")
    for i, build in enumerate(builds, 1):
        logger.info("[%d/%d] building scikit-misc %s", i, len(builds), build)
        wheels = INTERMEDIATES / "wheels" / build
        if wheels.exists():
            shutil.rmtree(wheels)
        wheels.mkdir(parents=True)
        cmd = [sys.executable, "-m", "pip", "wheel", "--no-deps", "--no-build-isolation", "--no-cache-dir", "--wheel-dir", str(wheels), str(INTERMEDIATES / "sources" / build)]
        with (RESULTS / "logs" / f"build-{build}.log").open("w") as stream:
            subprocess.run(cmd, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
        wheel_files = list(wheels.glob("*.whl"))
        if len(wheel_files) != 1:
            raise ValueError(f"expected one wheel for {build}, found {[p.name for p in wheel_files]}")
        target = INTERMEDIATES / "installs" / build
        if target.exists():
            shutil.rmtree(target)
        with zipfile.ZipFile(wheel_files[0]) as archive:
            archive.extractall(target)
    subprocess.run(["clang", "-dynamiclib", "-O2", str(EXPERIMENT_DIR / "src" / "modules" / "trace-alloc.c"), "-o", str(INTERMEDIATES / "trace-alloc.dylib")], check=True)
    metadata = {"platform": platform.platform(), "machine": platform.machine(), "python": platform.python_version(), "packages": {name: importlib.metadata.version(name) for name in ("numpy", "pyinstrument", "Cython", "meson-python", "meson", "ninja")}, "threads": {"OPENBLAS_NUM_THREADS": "1", "OMP_NUM_THREADS": "1", "VECLIB_MAXIMUM_THREADS": "1"}}
    for name, command in (("clang", ["clang", "--version"]), ("gfortran", ["gfortran", "--version"]), ("r", ["Rscript", "--version"])):
        metadata[name] = subprocess.check_output(command, text=True, stderr=subprocess.STDOUT).splitlines()[0]
    (RESULTS / "json" / "machine.json").write_text(json.dumps(metadata, indent=2) + "\n")
