# sparse-retention details

## run

```bash
Rscript experiments/exp_006_sparse_retention/run.R
Rscript shared/harness/growth-worker.R --experiments=006
```

- prerequisites are listed in the [protocol](../../../docs/003-experiment-protocol.md#run).
- `--no-profile` disables profiling.
- the candidate remains outside the package.
- both builds use source defaults; separate probe builds supply bytes and vertex counts.

## inputs

| input | path |
| --- | --- |
| prototype; cache reference | `shared/baseline/`; `shared/reference-nov6/` |
| candidate; before side | `variant.patch`; `../exp_005_package_source/variant.patch` |
| tied cases | `shared/harness/tied.R` |

## results

| quantity | value | source file and column |
| --- | --- | --- |
| standard observations | 45,000 | `.results/tables/growth.csv: N` |
| elapsed time; workspace | 24.7 ms; 12.6 MB | the same file: `median_seconds, requested_bytes` |
| ratios to R | 925× faster; 1,601× less workspace | local and shared R `growth.csv` |
| shared checks at default and small caps | 275/275 identical | `.results/json/summary.json: checks, cap_checks` |
| small retention caps | 0; 4,096; 65,536 B | the same file: `cap_checks` |
| tied comparisons | 15/15 identical in both builds | `.results/tables/tied-comparison.csv: before_identical, after_identical` |
| candidate / package source lines against R | +1,312 / −60; +1,253 / −59 | `.results/tables/lines-against-r.csv: part=source, added, removed` |
| added net source lines | 58 | the preceding source counts |
| ordinary workspace/package ratio | 0.75–0.90 | `.results/tables/timing-comparison.csv: after_native_bytes / before_native_bytes` |
| ordinary time/package ratio | 1.00–2.42 | the same file: `after_s / before_s` |
| two-predictor timing states | about 9.5 or 22 ms in either build | `.results/tables/timing-repeats.csv: case=d2-n2000-m80-cell0.05, seconds` |
| tied time/package; tied time/cache | 0.57–0.96; 0.42–0.79 | `.results/tables/tied-comparison.csv: after_baseline_s / before_baseline_s, after_ratio` |
| all needed vertices retained, before / after | 3 / 12 inputs | the same file: `needed_vertices, before_retained_vertices, after_retained_vertices` |
| memory exceeds R | 1.8–7.5× on 4 inputs | the same file: `after_baseline_native_bytes`; `r-tied.json: bytes` |

## tied cases

| case | vertices needed | retained before / after | neighbourhood | MB before / after | CPU seconds before / after | after/cache |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| spike-cloud-2-4096 | 775 | 682 / 775 | 819 | 69.5 / 20.2 | 0.090 / 0.083 | 0.42 |
| spike-cloud-2-8192 | 786 | 341 / 786 | 1,638 | 70.0 / 39.1 | 0.193 / 0.162 | 0.42 |
| spike-cloud-3-4096 | 1,357 | 512 / 1,357 | 819 | 74.3 / 47.2 | 0.299 / 0.221 | 0.42 |
| spike-cloud-3-8192 | 1,338 | 256 / 1,138 | 1,638 | 75.0 / 75.0 | 0.600 / 0.462 | 0.45 |
| spike-cloud-4-4096 | 2,747 | 409 / 1,862 | 819 | 91.4 / 91.5 | 1.141 / 0.920 | 0.61 |
| spike-cloud-4-8192 | 2,570 | 204 / 931 | 1,638 | 91.1 / 91.4 | 2.139 / 1.885 | 0.63 |
| repeated-grid-2-4096 | 289 | 289 / 289 | 15 | 29.6 / 1.4 | 0.039 / 0.036 | 0.55 |
| repeated-grid-2-8192 | 289 | 289 / 289 | 31 | 58.5 / 2.0 | 0.068 / 0.065 | 0.52 |
| repeated-grid-3-4096 | 343 | 343 / 343 | 15 | 47.2 / 2.4 | 0.056 / 0.053 | 0.62 |
| repeated-grid-3-8192 | 343 | 256 / 343 | 31 | 70.0 / 3.3 | 0.096 / 0.088 | 0.57 |
| repeated-grid-4-4096 | 625 | 409 / 625 | 15 | 73.1 / 6.5 | 0.147 / 0.128 | 0.68 |
| repeated-grid-4-8192 | 625 | 204 / 625 | 31 | 73.8 / 7.8 | 0.254 / 0.212 | 0.64 |
| grid-cloud-2-8192 | 2,611 | 341 / 2,611 | 15 | 77.8 / 11.9 | 0.391 / 0.313 | 0.47 |
| grid-cloud-3-8192 | 3,212 | 256 / 3,212 | 15 | 87.0 / 21.7 | 0.638 / 0.605 | 0.79 |
| grid-cloud-4-8192 | 5,699 | 204 / 5,699 | 15 | 116.8 / 53.7 | 1.415 / 0.808 | 0.71 |

- source: `tied-comparison.csv: needed_vertices, neighborhood_rows, *_retained_vertices, *_baseline_native_bytes, *_baseline_s, after_ratio`.

## limits

- the ordinary timing spread does not give a stable build-cost estimate.
- large neighbourhoods can still fill the retention cap.
- R tied times come from a separate run, so their ratios are rough.
- the remaining tied-grid memory excess is unresolved.
- [Public prediction limits](../../../docs/004-results.md#limits) still apply.

## outputs

| output | path |
| --- | --- |
| tables; summaries | `.results/tables/`; `.results/json/` |
| logs; profiles | `.results/logs/`; `.results/profile/` |
