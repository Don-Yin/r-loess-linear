loess_before <- find("loess")
predict_before <- find("predict")
library(loesslin)
stopifnot(identical(find("loess"), loess_before))
stopifnot(identical(find("predict"), predict_before))
stopifnot(identical(getNamespaceExports("loesslin"), "predict_se"))

capture <- function(expr) {
    warnings <- character()
    value <- withCallingHandlers(
        tryCatch(expr, error = function(e)
            structure(conditionMessage(e), class = "prediction_error")),
        warning = function(w) {
            warnings <<- c(warnings, conditionMessage(w))
            invokeRestart("muffleWarning")
        })
    list(value = value, warnings = warnings)
}

checks <- 0L
fit_errors <- 0L
check_prediction <- function(object, newdata = NULL) {
    stopifnot(identical(capture(predict_se(object, newdata)),
                        capture(stats::predict(object, newdata, se = TRUE)),
                        num.eq = FALSE, single.NA = FALSE))
    checks <<- checks + 1L
}

# Tied predictors, zero-width neighbourhoods, and both loess families.
set.seed(777)
for (scenario in c("rounded", "block_ties", "one_spike", "two_values"))
    for (d in 1:2) for (degree in 0:2)
        for (family in c("gaussian", "symmetric"))
            for (cell in c(0.2, 0)) for (span in c(0.2, 0.6)) {
                n <- 300
                x1 <- switch(scenario,
                    rounded = round(runif(n, 0, 3)),
                    block_ties = c(rep(1, 200), runif(100, 2, 3)),
                    one_spike = c(rep(0.5, 150), seq(1, 3, length.out = 150)),
                    two_values = sample(c(0, 1), n, TRUE))
                data <- data.frame(x1 = x1, y = sin(x1) + rnorm(n, sd = 0.3))
                if (d == 2)
                    data$x2 <- if (scenario == "two_values")
                        sample(c(0, 1), n, TRUE) else round(runif(n, 0, 2))
                formula <- if (d == 1) y ~ x1 else y ~ x1 + x2
                newdata <- data[sample(n, 40), setdiff(names(data), "y"), drop = FALSE]
                fit <- capture(stats::loess(formula, data, span = span,
                    degree = degree, family = family,
                    control = stats::loess.control(cell = cell)))$value
                if (inherits(fit, "prediction_error")) fit_errors <- fit_errors + 1L
                else check_prediction(fit, newdata)
            }
cat("ties: cumulative identical predictions =", checks,
    "; fits rejected by stats::loess =", fit_errors, "\n")

# One to four predictors, prior weights, and an out-of-range prediction.
set.seed(4242)
for (d in 1:4) for (n in c(150, 600)) for (degree in 1:2)
    for (cell in c(0, 0.2)) for (family in c("gaussian", "symmetric")) {
        X <- matrix(rnorm(n * d), n)
        colnames(X) <- paste0("x", seq_len(d))
        data <- data.frame(X, y = rowSums(sin(X)) + rnorm(n, sd = 0.3),
                           w = runif(n, 0.5, 2))
        formula <- stats::as.formula(paste("y ~", paste(colnames(X), collapse = "+")))
        newdata <- data[sample(n, 50), colnames(X), drop = FALSE]
        newdata[1, 1] <- newdata[1, 1] + 10
        fit <- capture(stats::loess(formula, data, weights = w,
            span = if (d >= 3) 0.9 else 0.5, degree = degree, family = family,
            control = stats::loess.control(cell = cell)))$value
        check_prediction(fit, newdata)
    }
cat("regular: cumulative identical predictions =", checks, "\n")

# Prediction counts and tree sizes from the shared exactness checks.
set.seed(99)
for (d in 1:4) for (cell in c(0.05, 0.2)) for (m in c(30, 200)) {
    n <- 400
    X <- matrix(runif(n * d, -3, 3), n)
    colnames(X) <- paste0("x", seq_len(d))
    data <- data.frame(X, y = rowSums(sin(X)) + rnorm(n, sd = 0.35))
    fit <- capture(stats::loess(stats::as.formula(paste("y ~", paste(colnames(X), collapse = "+"))),
        data, span = if (d == 1) 0.5 else 0.75,
        control = stats::loess.control(cell = cell)))$value
    newdata <- as.data.frame(matrix(runif(m * d, -2.5, 2.5), m,
                                    dimnames = list(NULL, colnames(X))))
    check_prediction(fit, newdata)
}
for (n in c(500, 2000, 10000)) {
    set.seed(20261105)
    x <- runif(n, -3, 3)
    y <- sin(x) + rnorm(n, sd = 0.35)
    fit <- stats::loess(y ~ x, span = 0.5)
    check_prediction(fit, data.frame(x = seq(min(x), max(x), length.out = 80)))
}
cat("shared cases: cumulative identical predictions =", checks, "\n")

# Public interface details, missing values, and the unchanged direct surface.
set.seed(20261111)
data <- data.frame(x = runif(150, -2, 2), z = runif(150, -20, 20))
data$y <- sin(data$x) + data$z/10 + rnorm(150, sd = 0.2)
data$w <- runif(150, 0.5, 2)
for (surface in c("interpolate", "direct"))
    for (family in c("gaussian", "symmetric")) for (degree in 0:2) {
        fit <- capture(stats::loess(y ~ x + z, data, weights = w, span = 0.9,
            family = family, degree = degree,
            control = stats::loess.control(surface = surface)))$value
        newdata <- data.frame(x = c(-1, 0, NA, NaN, 10), z = c(0, 1, 0, 1, 0),
                              row.names = letters[1:5])
        check_prediction(fit, newdata)
        check_prediction(fit, as.matrix(newdata))
        check_prediction(fit, data[FALSE, c("x", "z")])
        check_prediction(fit)
    }
for (surface in c("interpolate", "direct")) for (normalize in c(TRUE, FALSE)) {
    fit <- capture(stats::loess(y ~ x + z, data, weights = w, span = 0.9,
        parametric = "z", drop.square = "x", normalize = normalize,
        control = stats::loess.control(surface = surface)))$value
    check_prediction(fit, data[1:20, c("x", "z")])
    check_prediction(fit, expand.grid(x = c(-1, 0, 1), z = c(-10, 0, 10)))
    check_prediction(fit, data.frame(x = c(20, NA), z = c(20, NA)))
}
fit <- stats::loess(y ~ x, data)
check_prediction(fit, c(-1, 0, 1, NA))
check_prediction(fit, data.frame(z = 1))
check_prediction(fit, matrix(0, 3, 0))
check_prediction(fit, data.frame(x = c(Inf, -Inf)))
check_prediction(fit, data.frame(x = 10))
legacy_fit <- fit
legacy_fit$weights <- legacy_fit$robust <- NULL
check_prediction(legacy_fit, data.frame(x = c(-1, 0, 1)))
for (na.action in c("na.omit", "na.exclude")) {
    missing_data <- data
    missing_data$x[c(3, 20)] <- NA_real_
    fit <- stats::loess(y ~ x, missing_data, na.action = na.action)
    check_prediction(fit)
    check_prediction(fit, missing_data)
}
fit <- stats::loess(y ~ I(x^2), data, span = 0.9)
check_prediction(fit, data.frame(x = c(-1, 0, 1, NA)))
stopifnot(identical(capture(predict_se(list())),
                    capture(stats:::predict.loess(list(), se = TRUE))))
cat("total identical prediction comparisons =", checks, "\n")
cat("invalid-object error comparison = 1\n")
