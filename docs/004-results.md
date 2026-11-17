# results

macOS arm64, R 4.5.2. every build passes the 275 shared checks, bit for bit (256 against R, 19 against the cache reference); the package's own tests compare 324 more predictions (`tests/predict-se.R`). each experiment's page has its full numbers.

## against original R

| input | build | memory | against R | seconds | against R |
|---|---|---:|---:|---:|---:|
| one predictor, N = 45,000 | R, paired with `exp_000` | 20.3 GB | | 23.664 | |
| | `exp_000` cache | 20.3 GB | 1.00015 times more | 0.155 | 153 times faster |
| | R, paired with `exp_001` | 20.3 GB | | 22.893 | |
| | `exp_001` actual vertices | 15.6 MB | 1,301 times less | 0.114 | 201 times faster |
| | R, later comparisons | 20.3 GB | | 21.787 | |
| | `exp_002` prototype | 38.7 MB | 523 times less | 0.039 | 559 times faster |
| | `exp_003` independent reductions | 15.7–38.7 MB | 523–1,290 times less | 0.035–0.057 | 382–622 times faster |
| | `exp_005` package source | 15.7 MB | 1,290 times less | 0.038 | 573 times faster |
| | `exp_006` sparse retention | 11.7 MB | 1,724 times less | 0.038 | 573 times faster |
| `grid-cloud-3-8192` | R | 5.7 MB | | 1.26 | |
| | `exp_004` prototype | 87.0 MB | 15 times more | 29.5 | 23 times slower |
| | `exp_005` package source | 87.0 MB | 15 times more | 0.62 | 2.0 times faster |
| `grid-cloud-4-8192` | R | 7.2 MB | | 1.59 | |
| | `exp_005` package source | 116.8 MB | 16 times more | 1.35 | 1.2 times faster |
| | `exp_006` sparse retention | 53.7 MB | 7.5 times more | 0.86 | 1.8 times faster |

the cache adds 3,060,000 bytes to the native request; it leaves the quadratic capacity unchanged. storing coefficients for the actual vertices removes unused capacity in `exp_001`, but its worst case and the full returned influence matrix remain quadratic. its four-predictor input with 256 observations uses more native memory than R when all 256 vertices are needed. each of the first two experiments measures its own original-R time; later ordinary comparisons use `exp_002`'s R measurements.

all 15 tied inputs, each build as a multiple of R:

<img alt="exp_004 on the tied inputs" src="assets/exp_004-tied.png" width="270"> <img alt="exp_005 on the tied inputs" src="assets/exp_005-tied.png" width="270"> <img alt="exp_006 on the tied inputs" src="assets/exp_006-tied.png" width="270">

- on tied grids R's workspace is small, because its rows are 15 or 31 long, so the builds request more
- R's time on the tied inputs moved by up to 20% between runs, so those ratios are rough
- `predict(se = TRUE)` stops with an error on two tied inputs, in R and in every build, so the native routine is timed directly

## code size

the [experiment table](../experiments/README.md) shows the current added and removed physical source lines against original R. counts include copyright and modification notices and exclude the standalone `register.c` adapter. the range covers all eight `exp_003` variants, including the dropped one; `exp_007` leads with `deletions_only` and keeps its slower `reduced` comparison in the note.

the source records are `part=source`, columns `added` and `removed`, in each experiment's `.results/tables/lines-against-r.csv`. `Rscript shared/harness/lines-check.R` prepares the sources again and checks that table's column. [exp_008](../experiments/exp_008_python_skmisc/README.md) instead counts against pinned scikit-misc 0.5.3 in `lines-against-skmisc.csv`.

## how to read the figures

- upper figure: one input, memory requested across and time up, on linear axes. the R logo is original R, a numbered circle is the build of the experiment with that number, and the right panel enlarges the grey box
- tied figure: a row per tied input, the build as a multiple of R. R is the blue line at 1
- lower figure: R and the builds over N, measured with [atime](https://github.com/tdhock/atime) in the [notebook](005-compare.ipynb)
- memory is the native bytes a call requests. atime's kilobytes panel counts R's allocator instead, so the two do not agree
- the scripts are in `docs/figures/`; they need a local Python helper that is not in this repository, so the images are committed. the R logo is © The R Foundation, CC-BY-SA 4.0; [logo credits and terms](licences.md) also cover the Python mark
