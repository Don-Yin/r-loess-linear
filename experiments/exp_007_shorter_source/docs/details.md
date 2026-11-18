# shorter-source details

## run

```bash
Rscript experiments/exp_007_shorter_source/run.R
Rscript shared/harness/growth-worker.R --experiments=007
```

- prerequisites are listed in the [protocol](../../../docs/003-experiment-protocol.md#run).
- `--no-profile` disables profiling.
- all installations stay under `.intermediates/library-*`.
- the project package remains unchanged.

## inputs

| input | path |
| --- | --- |
| deletion / reduction patches | `patches/deletions-only.patch`; `variant.patch` |
| independent cost additions | `patches/add-*.patch` |
| shared checks; R sources | `shared/harness/`; `shared/reference-r/` |

## source size

| quantity | package | deletions_only | reduced | source file and column |
| --- | ---: | ---: | ---: | --- |
| physical lines | 3,982 | 2,757 | 2,518 | `.results/tables/source-lines.csv: variant, sum(source), sum(reduced)` |
| changes from package | — | +27 / −1,252 | +86 / −1,550 | `.results/json/summary.json: variants.*.source_lines` |
| changes against R | +1,333 / −576 | +1,277 / −1,748 | +1,187 / −1,896 | `.results/tables/lines-against-r.csv: part=source, added, removed` |
| package lines saved | — | 1,225 | another 239 | physical-line differences above |
| shared checks, each build/cap | — | 275/275 | same | `.results/tables/checks-*.csv: identical` |
| package predictions, each build/cap | — | 324 | same | `.results/json/tests-*.json` |
| public tied errors | 8 | same | same | `.results/tables/tied-timing.csv: public_error` |

## timings

| input | package | deletions_only | reduced | R | source file and column |
| --- | ---: | ---: | ---: | ---: | --- |
| ordinary N=20,000, queries=80 | 0.010 s | 0.010 s | 0.020 s | 4.092 s | `.results/tables/ordinary-timing.csv: source_s, deletions_only_s, reduced_s, r_s` |
| standard N=45,000, queries=80 | 0.0236 s | 0.0236 s | 0.0478 s | 22.879 s | local and shared `growth.csv: median_seconds` |
| ordinary N=2,000, queries=2,000 | 0.008 s | 0.007 s | 0.030 s | 0.119 s | `ordinary-timing.csv: source_s, deletions_only_s, reduced_s, r_s` |
| grid-cloud-4-8192, native | 1.431 s | 1.461 s | 2.357 s | 1.672 s | `tied-timing.csv: source_s, deletions_only_s, reduced_s, r_s` |
| standard workspace, bytes | 17,141,888 | same | same | 20,254,860,600 | local and shared `growth.csv: requested_bytes` |
| one-predictor cost/package | — | no material penalty | 2.00–3.75× | — | `ordinary-timing.csv: reduced_to_source` |

## independent additions

| addition | time/deletions_only | source file and column |
| --- | ---: | --- |
| `d-unified-plan` | 1.91–3.95 | `.results/tables/addition-timing.csv: implementation, to_deletions_only` |
| `p-canonical-ifit` | 1.01–1.17 | the same columns |
| `e-shared-features` | 1.020–1.027 | the same columns |
| `g-blas-axpy` | 0.993–1.015 | the same columns |
| rounds; calls per batch | 9; 20 | the same file: `rounds, batch` |

## limits and counting

- deletions remove unused routines, declarations, fitting entries and unreachable response-solving code.
- the extra reductions are a size-versus-speed comparison, not a package replacement.
- this deletion scope is specific to the standalone package.
- complete R stats still needs its fitter, direct predictor and declarations.
- public checks stop before the native NaN path on some tied inputs.
- the fused-sum reduction is excluded because it changes NaN bit patterns.
- the standalone harness inherits stats fitting entries after local entries are removed.
- installed-package checks cover the R wrapper.
- public prediction cannot delegate recursively to itself inside stats.
- custom subclasses, other BLAS libraries and other compilers are untested.
- package `R/predict-se.R` maps to R's complete `loess.R` in source counts.
- counts include notices and omit Makevars and package metadata.
- `register.c` remains a separate adapter.
- byte requests exclude fitting, fitted-value calls, other R objects and peak resident memory.

## outputs

| output | path |
| --- | --- |
| tables; summaries | `.results/tables/`; `.results/json/` |
| diagnostics; logs; profiles | `.results/diagnostics/`; `.results/logs/`; `.results/profile/` |
