# Python port details

## run

```bash
micromamba run -n r-loess-linear python experiments/exp_008_python_skmisc/run.py --sizes 100 174 303 529 922 1606 2800 4879 8503 14818 25823 45000 --rounds 3
Rscript shared/harness/growth-worker.R --experiments=008
```

```bash
micromamba run -n r-loess-linear python experiments/exp_008_python_skmisc/run.py --sizes 128 1000 --rounds 1
```

- use the existing `r-loess-linear` environment and its `environment.yml` dependencies.
- `Rscript`, Clang, GNU Fortran and `patch` must be on PATH.
- `--no-profile` disables entry and worker profiling.
- builds use private prefixes without environment installation, build isolation or dependency installation.
- the pinned archive is checksum-verified before building.

## inputs and parameters

| quantity | setting | source file and column |
| --- | --- | --- |
| scikit-misc version | 0.5.3 | `.results/json/source.json: source_url` |
| R source revision | 90840 | `shared/reference-r/verification.csv: revision, url` |
| patches | `cache.patch`; `actual-vertices.patch` | experiment source |
| data; query transfer | little-endian binary64 | `shared/harness/common.R: toby_data`; `.results/data/` |
| predictors; queries | 1; 80 | `src/modules/reference.R: n, m`; `shared/harness/common.R: toby_data` |
| degree; span; cell | 2; 0.5; 0.2 | `src/modules/worker.py: degree, span, cell` |
| fitting | Gaussian; unit weights; interpolation | `src/modules/worker.py: family, surface`, default weights |
| statistics; trace | approximate; exact | `src/modules/worker.py: statistics, trace_hat` |

- exact trace is distinct from exact-statistics fitting.
- the standard grid is the size list in the first command.
- both patches apply only to private source copies.

## checks

| comparison | result | source file and column |
| --- | --- | --- |
| Python arrays/scalars and repetitions | 1,520 bit-for-bit agreements | `.results/tables/checks.csv: bitwise_equal` |
| comparisons with R | 552; about 1e-14, not bit for bit | `.results/tables/r-comparisons.csv: max_abs_error, bitwise_equal` |
| maximum training-fit error | 1.059e-14 | the same file: `quantity=training_fit, max_abs_error` |
| maximum query-fit error | 1.057e-14 | the same file: `quantity=fit, max_abs_error` |
| maximum standard-error difference | 2.776e-16 | the same file: `quantity=se, max_abs_error` |
| absolute-error guard | 1e-10 | `src/modules/verification.py: max_abs_error` |

## standard endpoint

| quantity at N=45,000 | scikit-misc | cache | cache + actual vertices | source file and column |
| --- | ---: | ---: | ---: | --- |
| elapsed seconds | 21.354624 | 0.164253 | 0.089840 | `.results/tables/growth.csv: median_seconds` |
| user CPU seconds | 21.053191 | 0.100785 | 0.085640 | `.results/tables/summary.csv: prediction_user_seconds` |
| native workspace, bytes | 20,254,860,600 | 20,257,920,600 | 15,570,600 | `growth.csv: requested_bytes` |
| dense influence matrix, bytes | 28,800,000 | same | same | `summary.csv: influence_matrix_bytes` |
| tree vertices | 17 | same | same | `summary.csv: vertices` |
| speedup; workspace reduction | — | 130×; same | 238×; 1,301× less | the preceding time and byte rows |
| source-line changes | — | +57 / −20 | +161 / −75 | `lines-against-skmisc.csv: added, removed` |

## boundaries

| N | scikit-misc and cache | actual-vertex build | R standard errors | source file and column |
| ---: | --- | --- | --- | --- |
| 46,336 | succeed | 16,032,856 native B | succeed | `summary.csv: status, native_bytes`; `json/r-n46336.json: status` |
| 46,337 | SIGSEGV | 16,033,012 native B | workspace error | the same columns; `json/r-n46337.json: status, error` |
| 100,000 | SIGSEGV | 0.217486 s; 34,600,600 native B | workspace error | the same columns; `json/r-n100000.json: status, error` |
| signal return code | −11 | — | — | `.results/tables/measurements.csv: returncode` |

- SIGSEGV is the native invalid-memory-access signal.
- core dumps are disabled.
- only the known workspace-overflow crashes are expected; other worker or verification failures fail the run.

## source and allocation scope

| component | result | source |
| --- | --- | --- |
| Fortran | executable statements match after comment removal and diagnostic-name mapping | `source-comparison.csv: normalized_equal`; `port-comparison.csv: normalized_fortran_equal` |
| C | allocation and error interfaces require a port | `source-comparison.csv`; `.results/source-diffs/` |
| direct R allocation patch | does not apply | `.results/source-diffs/exp001-direct-apply.txt` |
| unchanged files | `S.h`, `loess.h`, `loess.c`, `predict.c`, Cython wrappers, `misc.c`, bundled BLAS/LINPACK | `source-comparison.csv: file, byte_equal` |
| formula domain | N ≥ 200; `nf=floor(N/2)` | `src/modules/memory.py: nf, capacity` |
| geometry bytes | `8*(50+7*N+5*nf)+4*(50+8*N)` | pinned `loessc.c`; `summary.csv: geometry_workspace_bytes` |
| coefficient bytes, baseline / actual | `20*nf*N` / `20*nf*V` | the same source |
| inverse-cache bytes | `4*V*N` | `cache.patch` |
| influence-matrix bytes | `8*m*N` | pinned `predict.c`; `summary.csv: influence_matrix_bytes` |

- `nf` is neighbourhood size and `V` is the actual vertex count.
- the port maps `loesswarn` to `ehg182` and preserves arithmetic order and geometry capacity.
- Fortran comparison keeps fixed-form statement columns.
- bundled BLAS and LINPACK have no file-level equality claim against R's linked library.
- C allocation ownership, error handling and the public Python signature remain intact.
- included workspace requests must match observed `calloc` requests individually.
- influence-matrix bytes come from the unchanged source formula, not an intercepted `malloc` call.
- other wrapper, fitting, NumPy, interpolation-only and allocator costs are excluded.
- peak resident memory includes imports and fitting; requested bytes are not isolated prediction RSS.
- profiles and allocation observation add overhead to short calls.
- imports, input reading and model fitting are outside prediction timing.
- the bundled BLAS implementation is serial and is not controlled by OpenMP.

## limits

- this is a regular one-predictor comparison, not a general linear-memory or end-to-end linear-time result.
- vertex growth can make both coefficient storage and the inverse cache quadratic.
- predicting at every training point makes the dense influence matrix quadratic.
- ties, small-cell trees, multiple predictors, nonunit weights and robust families are untested.
- extrapolation, normalisation changes, direct prediction and exact-statistics fitting are untested.
- confidence intervals, serialisation, concurrency and allocation failure are untested.
- R standard errors are unavailable beyond its workspace limit.
- native instruction-level profiling and cross-platform or cross-compiler bitwise guarantees are absent.
- platform coverage is listed in [results](../../../docs/004-results.md#limits).
- distribution and logo obligations are in [licences](../../../docs/licences.md#python-port).

## outputs

| output | path |
| --- | --- |
| results; comparisons | `.results/tables/` |
| inputs; arrays | `.results/data/`; `.results/arrays/` |
| metadata; logs; profiles | `.results/json/`; `.results/logs/`; `.results/profile/` |
| private archive, source and wheels | `.intermediates/` |
