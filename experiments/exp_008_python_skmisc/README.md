# exp_008_python_skmisc

## question

Does the actual-vertex coefficient storage from `exp_001_actual_vertices` transfer to Python's `skmisc.loess`, without changing fitted values or standard errors? Separate the inverse-neighbor cache from the allocation change so their time and byte effects are not conflated.

## result

The R patch needs porting, not direct application. The executable Fortran matches original R after removing comments and mapping R's `loesswarn` diagnostic name to scikit-misc's `ehg182`. The C allocation and error interfaces differ, and scikit-misc does not already contain the cache that `exp_001` assumes.

The experiment builds the same pinned scikit-misc source three ways: unchanged (`unpatched`), inverse-neighbor cache only (`cache`), then cache plus actual-vertex storage (`actual`). The cache reuses each neighbor's position instead of searching for it repeatedly. Actual-vertex storage allocates coefficients for the vertices the tree contains rather than its maximum capacity.

All 695 array/scalar checks are bit for bit identical across the Python changes and repeated processes. Against R, all 255 array comparisons are close but not bitwise identical: the maximum absolute differences are 1.059e-14 for training fits, 1.057e-14 for query fits and 1.874e-16 for standard errors.

One predictor, N = 45,000, 80 query points, span 0.5, and 17 tree vertices:

| quantity | unpatched | cache only | cache + actual vertices |
|---|---:|---:|---:|
| prediction wall seconds | 22.746587 | 0.170311 | 0.087046 |
| prediction user CPU seconds | 22.504745 | 0.102398 | 0.084385 |
| native bytes requested | 20,254,860,600 | 20,257,920,600 | 15,570,600 |
| dense influence matrix bytes | 28,800,000 | 28,800,000 | 28,800,000 |

The cache accounts for the large time reduction while retaining the quadratic coefficient reservation. Actual-vertex storage reduces the cache build's native request by about 1,301 times and gives a further time reduction here. The matrix is unchanged.

![Native bytes requested against prediction user CPU time for unpatched skmisc and both patched builds at N = 45,000](../../docs/assets/exp_008-result.png)

The Python mark identifies unpatched skmisc. The circles carry experiment number 8: the outlined circle is cache-only and the filled circle adds actual-vertex storage. Both axes are linear. The right panel enlarges the grey fast-time range and includes both patched builds. Native bytes exclude the unchanged dense influence matrix; they are allocation requests, not resident memory.

| N | unpatched / cache-only prediction | actual-vertex prediction | original R standard errors |
|---:|---|---|---|
| 46,336 | both succeed | succeeds; 16,032,856 native bytes | succeed |
| 46,337 | both terminate with SIGSEGV | succeeds; 16,033,012 native bytes | workspace error |
| 100,000 | both terminate with SIGSEGV | succeeds in 0.217486 wall seconds; 34,600,600 native bytes | workspace error |

At N = 46,337, unpatched skmisc and cache-only both crash with SIGSEGV; actual-vertex storage succeeds. Each cell has three fresh-process repetitions. SIGSEGV is the native invalid-memory-access signal; it is recorded as return code -11. The two above-limit sizes account for 12 expected crash processes. This covers regular one-predictor interpolation, not tied or worst-case trees, the direct surface or exact-statistics fitting. Fitting and the dense observation-by-query matrix remain; this is not a general linear-memory or end-to-end linear-time result.

## licences

The patched scikit-misc distribution retains scikit-misc 0.5.3's [BSD 3-Clause licence](https://github.com/has2k1/scikit-misc/blob/v0.5.3/LICENSE), held by Hassan Kibirige. Its `loessc.c` and `loessf.f` also carry the [AT&T loess notice](https://github.com/has2k1/scikit-misc/blob/v0.5.3/skmisc/loess/LICENSE.txt) for the work of Cleveland, Grosse and Shyu: use, copying, modification and distribution without fee are permitted, provided the entire notice remains in software copies and supporting documentation. The software is supplied without warranty. Keep both upstream licence texts with patched source or binary distributions; this does not replace the R package's licence.

The Python mark is © the Python Software Foundation, from its official [logo-device PNG](https://s3.dualstack.us-east-2.amazonaws.com/pythondotorg-assets/media/community/logos/python-logo-only.png), linked by the [Python logo page](https://www.python.org/community/logos/). Permission for this identifying use is the [PSF Trademark Usage Policy](https://www.python.org/psf/trademarks/#uses-that-never-require-approval), rather than the code licence. `docs/assets/python-logo.png` preserves the device and its proportions and adds ™ alongside it. Python and the Python logos are trademarks or registered trademarks of the Python Software Foundation; no affiliation is implied.

## how to run

Use the existing `r-loess-linear` micromamba environment, with the dependencies in this experiment's `environment.yml`, plus `Rscript`, Clang, GNU Fortran and `patch` on PATH:

```bash
micromamba run -n r-loess-linear python experiments/exp_008_python_skmisc/run.py --resources
```

`--no-profile` disables profiling in the entry and every worker. `--sizes 128 1000 --rounds 1` selects a smaller check. The default has three alternating-order rounds at each training size. Every build and measurement is private to this experiment; the run never installs scikit-misc into the micromamba environment. It builds wheels without build isolation or dependency installation, then unpacks them into separate private prefixes.

<details>
<summary>inputs, source comparison, outputs and every number</summary>

### inputs and source comparison

- scikit-misc **0.5.3**, pinned to its [PyPI source archive](https://files.pythonhosted.org/packages/8b/29/c82e425df0eccad26583225c2fc44470dfb5f731e111d37794a92aa8df93/scikit_misc-0.5.3.tar.gz). The immutable URL and checked archive digest are recorded in `.results/json/source.json: source_url, expected_sha256, downloaded_sha256`. Both patches apply only to private copies of that one archive.
- `shared/reference-r/`, fixed R source revision **90840**, and `shared/reference-nov6/`, the cache reference used by `exp_000_nov6_cache`.
- `experiments/exp_001_actual_vertices/variant.patch`, applied to a private copy of the cache reference to audit the second port.
- `shared/harness/common.R:toby_data()`, called in R to obtain the unchanged training data and query points. Inputs and R fitted/predicted arrays cross the language boundary as little-endian binary64, not CSV text.

The file-by-file comparison is `.results/tables/source-comparison.csv`, keyed by `file`; `byte_equal` tests the original bytes and `normalized_equal` removes comments and whitespace. For fixed-form Fortran, it retains the statement columns and maps only `loesswarn` to `ehg182`. A missing counterpart is not a claim of semantic equivalence.

| scikit-misc source | counterpart under `shared/reference-r/` | comparison and port consequence |
|---|---|---|
| `loessf.f` | `loessf.f` | Not byte-identical; executable source is identical after normalization. Differences are comments and the diagnostic symbol. Tree, smoothing, interpolation and the original neighbor search match. |
| `loessc.c` | `loessc.c` | Different after normalization: pointer-valued C arguments, `S.h`/`F77_SUB`, `calloc`/`free`, and global `error_status`/`error_message` replace R's headers, allocation and nonlocal error handling. Workspace formulas and the prediction sequence correspond. The cache arguments are absent. |
| `S.h` | none | Allocation and Fortran-name macros; retained unchanged. |
| `loess.h` | none | Native model, prediction and error-status structures and declarations; retained unchanged. R declares its entries in `modreg.h` instead. |
| `loess.c` | no same-name file; model wrapper is in `loess.R` | Native fitting/control and model lifetime. Its default trace switches to approximate for N at least 500; explicit `trace_hat="exact"` is required for this comparison. Retained unchanged. |
| `predict.c` | no same-name file; prediction wrapper is in `loess.R` | Allocates the dense query-by-observation influence matrix and reduces it to standard errors. Retained unchanged. |
| `_loess.pyx` | none | Python/Cython API, array ownership and conversion of native error status into Python exceptions; retained unchanged. |
| `c_loess.pxd` | none | Cython declarations of the native structures and calls; retained unchanged. |
| `misc.c` | none | Native allocation checks and distribution/interval helpers; retained unchanged. |
| `blas_lite.f` | none | Bundled basic linear-algebra routines. This reference folder does not vendor R's linked numerical library, so no file-equality claim is made. |
| `linpack_lite.f` | none | Bundled matrix-factorization routines. There is no corresponding file in this reference folder. Retained unchanged. |
| none | `loess.R` | R model and prediction integration, rather than a Python source file. |
| none | `modreg.h` | R headers and entry declarations. |
| none | `statsErr.h` | R error and translation integration. |
| none | `register.c` | Standalone measurement-library registration adapter, not an upstream Python file. |

Direct application of `exp_001` fails: `.results/source-diffs/exp001-direct-apply.txt` records the dry run. `cache.patch` ports the difference between the two R references; `actual-vertices.patch` then ports `exp_001`. They retain scikit-misc's allocation and error-status interfaces and do not alter its public call signature. Exact-statistics fitting continues to call the original search path; prediction enables the cache. The second patch separates geometry construction from smoothing, preserves geometry capacity and arithmetic order, and changes only the coefficient arrays' physical vertex stride. Its new allocations are checked and freed explicitly instead of using R's allocator.

Against the pinned unpatched scikit-misc 0.5.3 source, `cache.patch` is +57 / −20 physical lines; applying `cache.patch` then `actual-vertices.patch` gives +161 / −75 (`lines-against-skmisc.csv: variant=cache/actual, added/removed`). Counts include copyright and modification notices. These are final differences in `skmisc/loess/src/loessc.c` and `loessf.f`, not the sum of the two incremental patch sizes.

`.results/tables/port-comparison.csv: build, normalized_fortran_equal` checks all three complete Fortran files against their corresponding R targets. C is deliberately ported rather than substituted wholesale.

### numerical and timing method

N is the training observation count; there is one predictor and **80** evenly spaced prediction points across the training range. All builds use a Gaussian family, unit weights, degree **2**, span **0.5**, cell **0.2**, interpolation, `statistics="approximate"` and `trace_hat="exact"`. The last option computes the trace exactly; it is not the separate `statistics="exact"` fitting mode. The installed R reference uses its matching defaults.

The default sizes are **128, 512, 1,000, 2,048, 8,192, 16,384, 32,768, 45,000, 46,336, 46,337 and 100,000**. Each R reference and each Python build/size/repetition runs in a separate process. Native crash cases have core dumps disabled. The entry accepts the known workspace-overflow signal only for the unchanged and cache-only builds above the source's workspace limit; any other worker or verification failure fails the run.

`checks.csv: pair, n, replicate, quantity, bitwise_equal` compares all training fitted values, query fitted values, query standard errors, residual scale and degrees of freedom as binary64 payloads. Repetitions are also checked. `r-comparisons.csv: build, n, replicate, quantity, bitwise_equal, max_abs_error` compares R's binary training fits, query fits and available standard errors. It distinguishes bitwise equality from small floating-point error; its absolute-error guard is **1e-10**. R standard errors above its workspace limit are explicitly unavailable, not silently substituted.

The reported time is the median of three fresh-process calls to the public `predict(..., stderror=True)`; each round reverses the build order. Profiles and the allocation observer are enabled, so short calls include their overhead. The machine is shared, not an exclusive benchmark host. It excludes imports, input reading and model fitting, but includes interpolation, native workspace construction and Python's native standard-error reduction. `prediction_seconds` is wall time and `prediction_user_seconds` is process user CPU time. Profiles cover fitting and prediction separately in the actual workers, in addition to the entry's profile. A crashing prediction cannot finish an HTML profile; its completed fit profile and process exit remain recorded. Pyinstrument identifies the compiled call, not the native loop within it.

### requested bytes, not resident RAM

`measurements.csv` and `summary.csv` separate the geometry workspace, coefficient table, inverse-neighbor cache and influence matrix. For N at least 200, with `nf=floor(N/2)` and V actual vertices, the prediction workspaces request:

```text
geometry:     8*(50 + 7*N + 5*nf) + 4*(50 + 8*N)
coefficients: 20*nf*N                  # unpatched and cache
coefficients: 20*nf*V                  # actual
inverse:      4*V*N                    # cache and actual only
matrix:       8*80*N                   # every build, separately reported
```

`native_bytes` includes geometry, coefficients and the inverse cache, not the dense matrix. Each request included in this total is matched individually to an observed `calloc` request: `tables/allocations/*.csv: kind, count, item_bytes, requested_bytes, success`; `observed_native_bytes` must equal `native_bytes`. The matrix's `influence_matrix_bytes` comes from its unchanged source allocation formula, not an intercepted `malloc` measurement. The earlier interpolation-only `loess_grow` workspace, other wrapper allocations, Python/NumPy allocations, allocator overhead and private fitting state are excluded.

`peak_rss_bytes` is process-lifetime peak resident memory, including imports and fitting. Lazy memory commitment means a large virtual request need not become equally large resident RAM; neither this total RSS nor the request total is an isolated prediction-only resident-memory measure. Machine, dependency, compiler and thread settings are in `.results/json/machine.json`.

### every result number

The counts are `.results/json/summary.json: checks.cases, checks.bitwise_equal, r_checks.cases, expected_sigsegv_processes`; `sizes` and `rounds` record the design. The R error maxima are the maxima of `r-comparisons.csv: max_abs_error` selected by `quantity=training_fit`, `fit` and `se`. Every `bitwise_equal` in that R table is false.

The main result table is `summary.csv`, selected by `n=45000` and each `build`, columns `prediction_seconds`, `prediction_user_seconds`, `native_bytes`, `influence_matrix_bytes` and `vertices`. The byte reduction is `native_bytes[cache] / native_bytes[actual]`. The boundary table uses the same file's `n=46336,46337,100000`, `status`, `native_bytes` and `prediction_seconds`; the raw `measurements.csv: returncode` preserves every signal. R boundary states and error messages are `json/r-n46336.json`, `r-n46337.json` and `r-n100000.json: status,error`.

### outputs

- `.results/tables/summary.csv`, `measurements.csv`: medians and raw process outcomes, keyed by `build, n` and additionally `replicate` in the raw table.
- `.results/tables/checks.csv`, `r-comparisons.csv`: every numerical comparison.
- `.results/tables/source-comparison.csv`, `port-comparison.csv`, `lines-against-skmisc.csv`; `.results/source-diffs/`: source and port audit evidence and physical source-line differences.
- `.results/json/summary.json`, `source.json`, `machine.json`, `r-n*.json`, and one measurement JSON per successful worker.
- `.results/data/`, `.results/arrays/`: binary R inputs/reference arrays and complete Python output arrays.
- `.results/logs/`, `.results/profile/`: build/worker logs and default-on profiles.
- `.intermediates/`: the pinned archive, private source trees, wheels, unpacked prefixes and allocation observer. No scikit-misc build or installation is written outside this experiment.

### what is not covered

This is Toby's regular one-predictor setup, not the shared R regression suite or a worst-case bound. It does not cover tied inputs, small-cell vertex growth, multiple predictors, nonunit weights, robust families, normalization differences, extrapolation, the direct surface, exact-statistics fitting, confidence intervals, serialization, concurrency or allocation failure. The patches leave fitting and the dense influence matrix in place. The actual vertex count may grow with N, so coefficient storage and the inverse cache can still be quadratic; predicting at all training points also makes the dense output matrix quadratic. It is not a general linear-memory solution or an end-to-end linear-time result.

There is no cross-R standard-error reference above R's workspace limit, no native instruction-level profile, and no cross-platform or cross-compiler bitwise guarantee. Only macOS arm64 and this pinned source/build environment are measured. The cached builds are intentionally retained alongside the unchanged build because separating the two effects is the comparison being tested.

</details>
