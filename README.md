# loesslin

exact standard errors for R's `loess`, with memory that grows linearly with observations.

<a href="docs/assets/exp_005-result.png"><img alt="R and loesslin" src="docs/assets/exp_005-result.png" width="600"></a>

at N = 45,000: 968× faster than R with 1,182× less memory, bit for bit. [all experiments](experiments/README.md)

## install

install with `R CMD INSTALL .`.

## use

```r
x <- runif(2000, -3, 3); y <- sin(x) + rnorm(2000, sd = 0.35)
newdata <- data.frame(x = seq(-2.5, 2.5, length.out = 80))
fit <- loess(y ~ x, span = 0.5)
a <- predict(fit, newdata, se = TRUE)
b <- loesslin::predict_se(fit, newdata)
identical(a, b)
```

[licences](docs/licences.md): GPL-2 or GPL-3.

## documents

[context](docs/000-context.md) · [results](docs/004-results.md) · [notebook](docs/005-compare.ipynb) · [open questions](docs/002-open-questions.md) · [decisions](docs/001-decisions.md) · [protocol](docs/003-experiment-protocol.md)
