# experiment protocol

## run

```sh
Rscript experiments/exp_NNN_<slug>/run.R
Rscript shared/harness/lines-check.R
```

- R experiments require Rscript, C and Fortran compilers, BLAS, LAPACK, `patch` and `diff`.
- R experiments also require `jsonlite` and `bench`.
- the notebook additionally requires `atime` and `IRkernel`.
- the Python experiment uses its declared micromamba environment and requires Clang, GNU Fortran and `patch`.
- figures require Matplotlib, NumPy and the external `python_plotting_convention` and `slice_zoom` modules.
- `--no-profile` disables default profiling.
- run commands and experiment inputs are in each experiment's `docs/details.md`.

## rules

- apply independent patches to copies of their declared baseline.
- preserve R values, warnings, errors and NaN bit patterns without a tolerance.
- preserve floating-point and BLAS call order.
- record a slower or nonidentical change as a failed candidate.
- keep builds private to their owning experiment.

## measurement

| item | setting | source |
| --- | --- | --- |
| standard grid | `as.integer(10^seq(2, log10(45000), length.out=12))` | `shared/harness/growth.R: growth_sizes` |
| input | one predictor; queries=80; span=0.5; cell=0.2 | shared R artifact `manifest.json: input` |
| arithmetic-library threads | 1 | the same manifest: `runtime.threads, OMP_NUM_THREADS` |
| elapsed calls per R build / R baseline / Python build | 9 / 5 / 3 | each `growth.csv: repetitions` |
| R comparison checks | 256: 192 tied and 64 regular | `shared/harness/check.R` |
| cache-reference checks | 19: 16 prediction and 3 larger cases | the same file |
| ordinary timing | median user CPU | each ordinary timing table |
| requested memory | native workspace, excluding the returned influence matrix | `shared/harness/memory.R`; probe or allocation records |

- standard times exclude setup, fitting and collection outside each clock.
- requested bytes are not peak resident memory.
- source counts include notice lines and exclude the standalone `register.c` adapter.
- the reduction figure includes its dropped variant in the displayed range.
- the shorter-source figure leads with `deletions_only`.
- the Python figure compares against pinned scikit-misc rather than R.
- Python builds agree internally bit for bit; comparisons with R use the reported floating-point errors.
- tied R times were measured separately, so their time ratios are rough.
- the notebook's `atime` kilobytes omit native workspace outside R's allocator.

## read the figures

- axes are linear.
- the right panel enlarges the orange box.
- P denotes the package; other circles use experiment numbers.
- filled and outlined markers separate compared builds.

## sources

- read [source provenance](source-provenance.md).
- read [licence and logo terms](licences.md).
