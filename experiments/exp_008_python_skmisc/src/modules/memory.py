"""Match native allocation formulas to requests observed by dyld interposition."""

from __future__ import annotations

import csv
from pathlib import Path

FIRST_INVALID_N = 46_337


def requested_bytes(build: str, n: int, vertices: int, trace: Path) -> dict:
    """Verify native calloc requests; report the dense matrix by its source formula."""
    nf, capacity, m = n // 2, max(200, n), 80
    lv0, liv0 = 50 + 6 * capacity + n + 5 * nf, 50 + 6 * capacity + 2 * n
    coefficient_vertices = vertices if build == "actual" else capacity
    coefficient_bytes = 20 * nf * coefficient_vertices
    expected = [(lv0, 8), (liv0, 4), (vertices * nf, 4), (2 * vertices * nf, 8)] if build == "actual" else [(lv0 + 2 * nf * capacity, 8), (liv0 + nf * capacity, 4)]
    if build != "unpatched":
        expected.append((vertices * n, 4))
    with trace.open() as stream:
        requests = list(csv.DictReader(stream))
    observed = 0
    for count, item_bytes in expected:
        index = next((i for i, row in enumerate(requests) if row["kind"] == "calloc" and int(row["count"]) == count and int(row["item_bytes"]) == item_bytes and row["success"] == "1"), None)
        if index is None:
            raise ValueError(f"missing calloc({count}, {item_bytes}) for build={build}, n={n}, vertices={vertices}, trace={trace.name}")
        observed += int(requests.pop(index)["requested_bytes"])
    matrix_bytes = 8 * n * m
    geometry_bytes = 8 * lv0 + 4 * liv0
    inverse_bytes = 0 if build == "unpatched" else 4 * vertices * n
    native_bytes = geometry_bytes + coefficient_bytes + inverse_bytes
    if observed != native_bytes:
        raise ValueError(f"native byte mismatch for {build}, n={n}: observed={observed}, expected={native_bytes}")
    return {"vertices": vertices, "geometry_workspace_bytes": geometry_bytes, "coefficient_bytes": coefficient_bytes, "workspace_bytes": geometry_bytes + coefficient_bytes, "inverse_bytes": inverse_bytes, "influence_matrix_bytes": matrix_bytes, "native_bytes": native_bytes, "observed_native_bytes": observed, "trace_verified": True}
