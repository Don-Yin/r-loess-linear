# actual-vertex details

## run

```bash
Rscript experiments/exp_001_actual_vertices/run.R
Rscript shared/harness/growth-worker.R --experiments=001
Rscript shared/harness/lines.R
```

- prerequisites are listed in the [protocol](../../../docs/003-experiment-protocol.md#run).
- `--no-profile` disables profiling.
- builds use source defaults without preprocessor flags.

## inputs

| input | path |
| --- | --- |
| cache source; allocation patch | `shared/reference-nov6/`; `variant.patch` |
| R source | `shared/reference-r/` |
| checks; ordinary cases | `shared/harness/check.R`; `shared/harness/speed.R` |

## results

| quantity | R | actual-vertex build | source file and column |
| --- | ---: | ---: | --- |
| standard observations | 45,000 | same | `.results/tables/growth.csv: N` |
| elapsed seconds | 22.879 | 0.098 | shared R `growth.csv`; local `.results/tables/growth.csv: median_seconds` |
| native workspace, bytes | 20,254,860,600 | 15,570,600 | the same tables: `requested_bytes` |
| returned matrix, bytes | 28,800,000 | same | `shared/harness/memory.R: reference_bytes, L` |
| speed; workspace ratios | — | 233× faster; 1,301× less | the preceding time and byte rows |
| tree vertices; reserved capacity | — | 17; 45,000 | fitted `kd$parameter[nv]`; `shared/harness/memory.R` |
| shared checks | — | 275/275 identical | `.results/tables/checks.csv: identical` |
| ordinary timing outputs | — | 9/9 identical | `.results/tables/timing.csv: identical` |
| source lines against R | — | +176 / −82 | `.results/tables/lines-against-r.csv: part=source, added, removed` |
| lines including adapter | — | +178 / −84 | the same file: `part=total, added, removed` |
| full-tree case: predictors; observations; vertices | — | 4; 256; 256 | `.results/tables/timing.csv: d, n, vertices` |
| full-tree workspace, bytes | 2,244,696 | 2,506,840 | the same file: `r_native_bytes, native_bytes` |

## limits

- this is not a general linear-memory solution.
- memory uses source allocation formulas, not probes.
- coefficient storage and the inverse-neighbour cache can remain quadratic as the tree grows.
- geometry capacity, exact-fitting allocations and the direct surface are unchanged.
- the cache can increase workspace when every reserved vertex is needed.
- the full influence matrix remains quadratic for predictions at all training points.
- requested bytes exclude R copies, temporary arrays, allocator overhead and peak resident memory.
- separate direct-surface and exact-fitting regression suites are absent.
- R comparisons stop at its workspace limit.

## outputs

| output | path |
| --- | --- |
| tables | `.results/tables/` |
| summary | `.results/json/summary.json` |
| logs; profiles | `.results/logs/`; `.results/profile/` |
