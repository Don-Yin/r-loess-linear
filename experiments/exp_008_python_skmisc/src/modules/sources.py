"""Fetch the pinned source and record its differences from the R core."""

from __future__ import annotations

import difflib
import hashlib
import json
import logging
import re
import shutil
import subprocess
import tarfile
import urllib.request
from pathlib import Path

from ..utils.output import write_table
from ..utils.paths import EXPERIMENT_DIR, RESULTS

logger = logging.getLogger(__name__)
VERSION = "0.5.3"
ARCHIVE = f"scikit_misc-{VERSION}.tar.gz"
URL = f"https://files.pythonhosted.org/packages/8b/29/c82e425df0eccad26583225c2fc44470dfb5f731e111d37794a92aa8df93/{ARCHIVE}"
SHA256 = "ae1bd75c9f903295dd4e90af8d28d09d31a5e6432909f89927da231b3fbcc1e1"
INTERMEDIATES = EXPERIMENT_DIR / ".intermediates"
PROJECT = EXPERIMENT_DIR.parents[1]


def normalized(text: str, *, fortran: bool) -> list[str]:
    """Remove comments and whitespace, mapping only the diagnostic symbol."""
    if fortran:
        lines = [line[6:72] for line in text.splitlines() if line and line[0] not in "cC*!" and line.strip()]
        text = "\n".join(lines).replace("loesswarn", "ehg182")
    else:
        text = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
    return [re.sub(r"\s+", "", line) for line in text.splitlines() if line.strip()]


def compare_sources(clean: Path) -> None:
    """Save a file-by-file table, normalized comparisons, and readable diffs."""
    src = clean / "skmisc" / "loess" / "src"
    reference = PROJECT / "shared" / "reference-r"
    rows = []
    diff_dir = RESULTS / "source-diffs"
    diff_dir.mkdir(parents=True, exist_ok=True)
    for name in sorted({p.name for p in src.iterdir()} | {p.name for p in reference.iterdir() if p.suffix in (".c", ".f", ".h", ".R")}):
        left, right = reference / name, src / name
        row = {"file": name, "r_file": f"shared/reference-r/{name}" if left.exists() else "", "skmisc_file": f"skmisc/loess/src/{name}" if right.exists() else "", "byte_equal": False, "normalized_equal": False}
        if left.exists() and right.exists():
            a, b = left.read_text(), right.read_text()
            row.update(byte_equal=a == b, normalized_equal=normalized(a, fortran=name.endswith(".f")) == normalized(b, fortran=name.endswith(".f")))
            (diff_dir / f"{name}.diff").write_text("".join(difflib.unified_diff(a.splitlines(True), b.splitlines(True), fromfile=row["r_file"], tofile=row["skmisc_file"])))
            row["relationship"] = "same executable Fortran after diagnostic-symbol mapping" if row["normalized_equal"] else "different integration layer"
        else:
            row["relationship"] = "R-only integration" if left.exists() else "scikit-misc-only integration or bundled numerical support"
        rows.append(row)
    write_table("source-comparison.csv", rows)
    core = next(row for row in rows if row["file"] == "loessf.f")
    if not core["normalized_equal"]:
        raise ValueError("loessf.f differs from shared/reference-r after normalization; the port requires a new review")


def audit_ports(clean: Path) -> None:
    """Check both Fortran ports against their R targets, without patching shared files."""
    actual_reference = INTERMEDIATES / "r-actual-reference"
    if actual_reference.exists():
        shutil.rmtree(actual_reference)
    shutil.copytree(PROJECT / "shared" / "reference-nov6", actual_reference)
    original_patch = PROJECT / "experiments" / "exp_001_actual_vertices" / "variant.patch"
    with original_patch.open() as stream:
        subprocess.run(["patch", "--batch", "--fuzz=0", "-p1"], cwd=actual_reference, stdin=stream, check=True)
    rows = []
    for build, reference in (("unpatched", PROJECT / "shared" / "reference-r"), ("cache", PROJECT / "shared" / "reference-nov6"), ("actual", actual_reference)):
        source = INTERMEDIATES / "sources" / build / "skmisc" / "loess" / "src" / "loessf.f"
        equal = normalized(source.read_text(), fortran=True) == normalized((reference / "loessf.f").read_text(), fortran=True)
        rows.append({"build": build, "normalized_fortran_equal": equal})
        if not equal:
            raise ValueError(f"ported Fortran for {build} differs from its R target after normalization")
    write_table("port-comparison.csv", rows)
    with original_patch.open() as stream:
        direct = subprocess.run(["patch", "--dry-run", "--batch", "--fuzz=0", "-p1"], cwd=clean / "skmisc" / "loess" / "src", stdin=stream, capture_output=True, text=True)
    (RESULTS / "source-diffs" / "exp001-direct-apply.txt").write_text(direct.stdout + direct.stderr)
    if direct.returncode != 1:
        raise ValueError(f"expected direct R patch to require porting, got dry-run returncode={direct.returncode}")


def prepare_sources() -> None:
    """Create three private source trees from one verified PyPI archive."""
    for name in ("tables", "json", "logs", "profile", "arrays", "data"):
        (RESULTS / name).mkdir(parents=True, exist_ok=True)
    INTERMEDIATES.mkdir(parents=True, exist_ok=True)
    archive = INTERMEDIATES / ARCHIVE
    if not archive.exists():
        logger.info("downloading scikit-misc %s from %s", VERSION, URL)
        urllib.request.urlretrieve(URL, archive)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if digest != SHA256:
        raise ValueError(f"source archive {archive.name} sha256={digest}, expected {SHA256}")
    clean = INTERMEDIATES / f"scikit_misc-{VERSION}"
    if clean.exists():
        shutil.rmtree(clean)
    with tarfile.open(archive) as source:
        source.extractall(INTERMEDIATES, filter="data")
    compare_sources(clean)
    source_manifest = {"package": "scikit-misc", "version": VERSION, "source_url": URL, "expected_sha256": SHA256, "downloaded_sha256": digest, "builds": ["unpatched", "cache", "actual"]}
    (RESULTS / "json" / "source.json").write_text(json.dumps(source_manifest, indent=2) + "\n")
    for build in source_manifest["builds"]:
        target = INTERMEDIATES / "sources" / build
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(clean, target)
        patches = () if build == "unpatched" else ("cache.patch",) if build == "cache" else ("cache.patch", "actual-vertices.patch")
        for name in patches:
            with (EXPERIMENT_DIR / name).open() as stream:
                subprocess.run(["patch", "--batch", "--fuzz=0", "-p1"], cwd=target, stdin=stream, check=True)
    audit_ports(clean)
