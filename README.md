# loesslin

exact standard errors for R's `loess` with memory that grows linearly with the number of observations, for `predict(se = TRUE)` on the interpolation surface.

## experiments

every build passes the same 275 exactness checks, bit for bit (256 against R, 19 against the Nov 6 patch). numbers are against original R at N = 45,000, or on the tied input named. click an experiment for its figures; [how to read them](docs/004-results.md#how-to-read-the-figures).

| experiment | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;result&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | memory against&nbsp;R | time against&nbsp;R |
|---|---|---|---|
| [exp_000 baseline](experiments/exp_000_baseline_prototype/README.md) | <a href="docs/assets/exp_000-result.png"><img alt="exp_000 result" src="docs/assets/exp_000-result.png" width="400"></a><br><a href="docs/assets/exp_000-atime.png"><img alt="exp_000 measured with atime" src="docs/assets/exp_000-atime.png" width="400"></a> | **523×&nbsp;less** | **559×&nbsp;faster** |
| [exp_001 reductions](experiments/exp_001_reductions/README.md) | <a href="docs/assets/exp_001-result.png"><img alt="exp_001 result" src="docs/assets/exp_001-result.png" width="400"></a><br><a href="docs/assets/exp_001-atime.png"><img alt="exp_001 measured with atime" src="docs/assets/exp_001-atime.png" width="400"></a> | **523&nbsp;to&nbsp;1,290×&nbsp;less** | **382&nbsp;to&nbsp;622×&nbsp;faster** |
| [exp_002 worst case](experiments/exp_002_worst_case/README.md) | <a href="docs/assets/exp_002-result.png"><img alt="exp_002 result" src="docs/assets/exp_002-result.png" width="400"></a><br><a href="docs/assets/exp_002-atime.png"><img alt="exp_002 measured with atime" src="docs/assets/exp_002-atime.png" width="400"></a> | one tied point: **36×&nbsp;less**<br>tied grid: **15×&nbsp;more** | one tied point: **84×&nbsp;faster**<br>tied grid: **23×&nbsp;slower** |
| [exp_003 package source](experiments/exp_003_package_source/README.md) | <a href="docs/assets/exp_003-result.png"><img alt="exp_003 result" src="docs/assets/exp_003-result.png" width="400"></a><br><a href="docs/assets/exp_003-atime.png"><img alt="exp_003 measured with atime" src="docs/assets/exp_003-atime.png" width="400"></a> | **1,290×&nbsp;less**<br>tied grid: **15×&nbsp;more** | **573×&nbsp;faster**<br>tied grid: **2.0×&nbsp;faster** |
| [exp_004 sparse retention](experiments/exp_004_sparse_retention/README.md) | <a href="docs/assets/exp_004-result.png"><img alt="exp_004 result" src="docs/assets/exp_004-result.png" width="400"></a><br><a href="docs/assets/exp_004-atime.png"><img alt="exp_004 measured with atime" src="docs/assets/exp_004-atime.png" width="400"></a> | **1,724×&nbsp;less**<br>tied grid: **7.5×&nbsp;more** | **573×&nbsp;faster**<br>tied grid: **1.8×&nbsp;faster** |

on the tied grids R itself needs little memory, so the builds request more: [details](docs/004-results.md#against-original-r).

## compare the methods

after `R CMD INSTALL .` and `Rscript experiments/exp_000_baseline_prototype/run.R` (needs `patch`, `diff` and `jsonlite`), from the repository root:

```r
for (file in c("common.R", "speed.R", "memory.R")) source(file.path("shared", "harness", file))
nov6 <- load_loess("experiments/exp_000_baseline_prototype/.intermediates/reference-nov6", "loesssent.so")
data <- toby_data(20000)                     # the setup of tdhock/atime#135
calls <- list(
  R        = function() predict(data$fit, data$nd, se = TRUE),
  nov6     = function() nov6$predict.loess(data$fit, data$nd, se = TRUE, cache = TRUE),
  loesslin = function() loesslin::predict_se(data$fit, data$nd))
sapply(lapply(calls, function(call) call()), same, calls$R())    # bit for bit
interleaved_seconds(calls, rounds = 3L)                          # user CPU seconds, median
c(R = reference_bytes(1, 20000, 80, 0.5, 2, 0)[["native"]],      # bytes of workspace requested
  nov6 = reference_bytes(1, 20000, 80, 0.5, 2, data$fit$kd$parameter[["nv"]])[["native"]])
```

the [notebook](docs/005-compare.ipynb) does this over N and repeats every experiment with atime.

## use

one function, on a fit from R's own `loess()`:

```r
x <- runif(2000, -3, 3); y <- sin(x) + rnorm(2000, sd = 0.35)
newdata <- data.frame(x = seq(-2.5, 2.5, length.out = 80))
fit <- loess(y ~ x, span = 0.5)
a <- predict(fit, newdata, se = TRUE)      # R
b <- loesslin::predict_se(fit, newdata)    # this package
identical(a, b)
```

install with `R CMD INSTALL .` (R 4.5 with C and Fortran compilers). early: checked on macOS arm64 with R 4.5.2 only.

## documents

[context](docs/000-context.md) · [results](docs/004-results.md) · [notebook](docs/005-compare.ipynb) · [open questions](docs/002-open-questions.md) · [decisions](docs/001-decisions.md) · [experiment protocol](docs/003-experiment-protocol.md)
