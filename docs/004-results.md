# results

## against R

| input | build | workspace | against R | time | against R |
| --- | --- | ---: | ---: | ---: | ---: |
| standard | R | 20.25 GB | — | 22.9 s | — |
| standard | cache | 20.26 GB | 1.00015× more | 186 ms | 123× faster |
| standard | actual vertices | 15.6 MB | 1,301× less | 98.2 ms | 233× faster |
| standard | prototype | 40.2 MB | 504× less | 22.9 ms | 999× faster |
| standard | independent reductions | 17.1–40.2 MB | 504–1,182× less | 23.2–43.7 ms | 523–986× faster |
| standard | default-cap prototype | 40.2 MB | 504× less | 23.4 ms | 978× faster |
| standard | package | 17.1 MB | 1,182× less | 23.6 ms | 968× faster |
| standard | sparse retention | 12.6 MB | 1,601× less | 24.7 ms | 925× faster |
| standard | deletions | 17.1 MB | 1,182× less | 23.6 ms | 970× faster |
| standard | extra reductions | 17.1 MB | 1,182× less | 47.8 ms | 479× faster |
| grid-cloud-3-8192 | R | 5.7 MB | — | 1.26 s | — |
| same grid | prototype | 87.0 MB | 15× more | 31.1 s | 25× slower |
| same grid | package | 87.0 MB | 15× more | 0.64 s | 2.0× faster |
| grid-cloud-4-8192 | R | 7.2 MB | — | 1.59 s | — |
| same grid | package | 116.8 MB | 16× more | 1.40 s | 1.1× faster |
| same grid | sparse retention | 53.7 MB | 7.5× more | 0.81 s | 2.0× faster |

- standard rows use each experiment's `growth.csv: median_seconds, requested_bytes`.
- R standard rows use `experiments/shared/artifacts/r-growth/growth.csv`.
- tied rows use `tied-comparison.csv` and `docs/figures/result/r-tied.json: seconds, bytes`.

<img alt="prototype tied inputs" src="assets/exp_004-tied.png" width="270">
<img alt="package tied inputs" src="assets/exp_005-tied.png" width="270">
<img alt="sparse tied inputs" src="assets/exp_006-tied.png" width="270">

## limits

| item | coverage or limit | source |
| --- | --- | --- |
| standard input | N=45,000; one predictor | shared R `manifest.json: input`; `growth.csv: N` |
| minimum R | 4.5.0 | `DESCRIPTION: Depends` |
| tested platform only | macOS arm64, R 4.5.2 | exp_008 `machine.json: platform, r` |
| toolchain | C and Fortran compilers, BLAS, LAPACK | `DESCRIPTION: SystemRequirements` |
| R shared checks | 275/275, bit for bit | each `.results/tables/checks.csv: identical` |
| package predictions | 324 comparisons | `tests/predict-se.R` |
| public tied errors | 8: six repeated grids and two grid clouds | exp_004 `default-cap-findings.csv: public_error` |
| first invalid workspace in Toby's setup | N=46,337; R stops and scikit-misc crashes | exp_002 `memory.csv: n, r_runs`; exp_008 `summary.csv: status` |
| Python / R agreement | about 1e-14, not bit for bit | exp_008 `r-comparisons.csv: max_abs_error, bitwise_equal` |
| tied-grid neighbourhoods | 15 or 31 points | exp_004 `default-cap-findings.csv: neighborhood_rows` |

- actual-vertex storage is not a general linear-memory solution.
- full influence matrices can remain quadratic.
- tied errors use native standard-error routines for the comparison.
- tied R times come from a separate run, so their ratios are rough.
- sparse cost has [two timing states](../experiments/exp_006_sparse_retention/docs/details.md#results).
- source-line counts and wrapper-mapping limits are in each experiment's details.

## how to read the figures

- read the [measurement method](003-experiment-protocol.md#measurement).
- read the [logo credits and terms](licences.md).
