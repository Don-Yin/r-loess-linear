# loesslin

exact standard errors for R's `loess` with memory that grows linearly with the number of observations, for `predict(se = TRUE)` on the interpolation surface.

## experiments

at N = 45,000 the package requests 1,290× less memory than R and runs 573× faster, with the same output bit for bit.

<a href="docs/assets/exp_005-result.png"><img alt="R and this package at N = 45,000" src="docs/assets/exp_005-result.png" width="600"></a>

[all experiments](experiments/README.md)

## compare the methods

after `R CMD INSTALL .` and `Rscript experiments/exp_002_baseline_prototype/run.R` (needs `patch`, `diff` and `jsonlite`), from the repository root:

```r
for (file in c("common.R", "speed.R", "memory.R")) source(file.path("shared", "harness", file))
nov6 <- load_loess("experiments/exp_002_baseline_prototype/.intermediates/reference-nov6", "loesssent.so")
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

the [notebook](docs/005-compare.ipynb) does this over N and repeats the R experiments with atime.

## use

on a fit from R's `loess()`:

```r
x <- runif(2000, -3, 3); y <- sin(x) + rnorm(2000, sd = 0.35)
newdata <- data.frame(x = seq(-2.5, 2.5, length.out = 80))
fit <- loess(y ~ x, span = 0.5)
a <- predict(fit, newdata, se = TRUE)      # R
b <- loesslin::predict_se(fit, newdata)    # this package
identical(a, b)
```

install with `R CMD INSTALL .` (R 4.5 with C and Fortran compilers). early: checked on macOS arm64 with R 4.5.2 only.

Code: [GPL-2 or GPL-3](docs/licences.md). Figure logos: R © The R Foundation, CC-BY-SA 4.0; Python © the Python Software Foundation, used under its trademark policy. [Sources, terms and transformations](docs/licences.md).

## documents

[context](docs/000-context.md) · [results](docs/004-results.md) · [notebook](docs/005-compare.ipynb) · [open questions](docs/002-open-questions.md) · [decisions](docs/001-decisions.md) · [experiment protocol](docs/003-experiment-protocol.md)
