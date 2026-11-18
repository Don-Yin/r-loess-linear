# cache details

## run

```bash
Rscript experiments/exp_000_nov6_cache/run.R
Rscript shared/harness/growth-worker.R --experiments=000
Rscript shared/harness/lines.R
```

- prerequisites are listed in the [protocol](../../../docs/003-experiment-protocol.md#run).
- `--no-profile` disables profiling.
- builds use source defaults without preprocessor flags.

## inputs

| input | path |
| --- | --- |
| cache source | `shared/reference-nov6/` |
| R source | `shared/reference-r/` |
| ordinary cases | `shared/harness/speed.R: timing_cases, timing_data` |
| checks | `shared/harness/check.R` |

## results

| quantity | value | source file and column |
| --- | --- | --- |
| standard input | N=45,000; queries=80; span=0.5 | `.results/tables/growth.csv: N`; `shared/harness/common.R: toby_data` |
| R time; workspace | 22.879 s; 20,254,860,600 B | `experiments/shared/artifacts/r-growth/growth.csv: median_seconds, requested_bytes` |
| cache time; workspace | 0.186 s; 20,257,920,600 B | `.results/tables/growth.csv: median_seconds, requested_bytes` |
| speedup; added workspace | 123×; 3,060,000 B | the preceding tables: time ratio, requested-byte difference |
| returned influence matrix, each build | 28,800,000 B | `shared/harness/memory.R: reference_bytes, L` |
| shared checks | 275/275 identical | `.results/tables/checks.csv: identical` |
| ordinary timing outputs | 9/9 identical | `.results/tables/timing.csv: identical` |
| source lines against R | +74 / −27 | `.results/tables/lines-against-r.csv: part=source, added, removed` |
| lines including build adapter | +76 / −29 | the same file: `part=total, added, removed` |

## limits

- memory uses source allocation formulas, not probes.
- inverse-neighbour lookup preserves the last-match rule.
- coefficient capacity and the inverse-neighbour cache retain a quadratic worst case.
- predicting at every training point makes the returned influence matrix quadratic.
- native workspace excludes R input copies, temporary arrays and allocator overhead.
- requested bytes are not peak resident memory.
- the direct surface and exact-fitting allocations are unchanged.
- separate direct-surface and exact-fitting regression suites are absent.

## outputs

| output | path |
| --- | --- |
| tables | `.results/tables/` |
| summary | `.results/json/summary.json` |
| logs; profiles | `.results/logs/`; `.results/profile/` |
