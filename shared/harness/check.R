# Exactness of a built variant against the installed R and against the Nov 6 patch: the fit, predict(se = TRUE),
# warnings and errors, bit for bit (275 cases).
# worker: Rscript <this file> <variant dir> <reference dir> <output csv> [profile path]
args <- commandArgs(TRUE); dir <- args[1]; ref <- args[2]; out <- args[3]
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
source(file.path(dirname(normalizePath(gsub("~+~", " ", self, fixed = TRUE))), "common.R"))
start_profile(args[4])
e <- load_loess(dir, "loessfactorpredict.so"); nov6 <- load_loess(ref, "loesssent.so")
rows <- list()
add <- function(suite, id, ok) rows[[length(rows) + 1]] <<- data.frame(suite, id, ok)
# a is R's captured fit and b the build's: the same warnings, then the same error, or the same fit (apart
# from its call) and the same predict(se = TRUE) with the same warnings.
agree <- function(a, b, nd) {
  if (inherits(a$value, "error-message") || inherits(b$value, "error-message")) return(same(a, b))
  pa <- capture(stats::predict(a$value, nd, se = TRUE)); pb <- capture(e$predict.loess(b$value, nd, se = TRUE))
  a$value$call <- b$value$call <- NULL
  same(a, b) && same(pa, pb)
}

# suite ties: tied x values, zero-width neighbourhoods, both families (192 cases)
set.seed(777)
for (scen in c("rounded", "block_ties", "one_spike", "two_values")) for (d in 1:2) for (deg in 0:2)
  for (fam in c("gaussian", "symmetric")) for (cell in c(0.2, 0)) for (span in c(0.2, 0.6)) {
    n <- 300
    x1 <- switch(scen,
      rounded = round(runif(n, 0, 3)),
      block_ties = c(rep(1, 200), runif(100, 2, 3)),
      one_spike = one_spike(n),
      two_values = sample(c(0, 1), n, TRUE))
    df <- data.frame(x1 = x1, y = sin(x1) + rnorm(n, sd = .3))
    if (d == 2) df$x2 <- if (scen == "two_values") sample(c(0, 1), n, TRUE) else round(runif(n, 0, 2))
    f <- if (d == 1) y ~ x1 else y ~ x1 + x2
    nd <- df[sample(n, 40), setdiff(names(df), "y"), drop = FALSE]
    ctl <- loess.control(surface = "interpolate", cell = cell)
    a <- capture(stats::loess(f, df, span = span, degree = deg, family = fam, control = ctl))
    b <- capture(e$loess(f, df, span = span, degree = deg, family = fam, control = ctl))
    add("ties", paste(scen, d, deg, fam, cell, span, sep = "-"), agree(a, b, nd))
  }

# suite regular: 1 to 4 predictors, prior weights, one point outside the data range (64 cases)
set.seed(4242)
for (d in 1:4) for (n in c(150, 600)) for (deg in 1:2) for (cell in c(0, 0.2)) for (fam in c("gaussian", "symmetric")) {
  X <- matrix(rnorm(n * d), n); colnames(X) <- paste0("x", 1:d)
  df <- data.frame(X, y = rowSums(sin(X)) + rnorm(n, sd = .3), w = runif(n, .5, 2))
  f <- reformulate(colnames(X), response = "y")
  span <- if (d >= 3) 0.9 else 0.5
  nd <- df[sample(n, 50), colnames(X), drop = FALSE]; nd[1, 1] <- nd[1, 1] + 10
  ctl <- loess.control(surface = "interpolate", cell = cell)
  a <- capture(stats::loess(f, df, weights = w, span = span, degree = deg, family = fam, control = ctl))
  b <- capture(e$loess(f, df, weights = w, span = span, degree = deg, family = fam, control = ctl))
  add("regular", paste(d, n, deg, cell, fam, sep = "-"), agree(a, b, nd))
}

# suite vs-nov6: predict(se = TRUE) on R's fit against the Nov 6 patch, 1 to 4 predictors (16 cases)
set.seed(99)
for (d in 1:4) for (cell in c(0.05, 0.2)) for (m in c(30, 200)) {
  data <- fit_data(matrix(runif(400 * d, -3, 3), 400), m, if (d == 1) 0.5 else 0.75, cell)
  pa <- capture(nov6$predict.loess(data$fit, data$nd, se = TRUE, cache = TRUE))
  pb <- capture(e$predict.loess(data$fit, data$nd, se = TRUE))
  add("vs-nov6", paste(d, cell, m, sep = "-"), same(pa, pb))
}

# suite toby: Toby's setup against the Nov 6 patch
for (N in c(500, 2000, 10000)) {
  data <- toby_data(N)
  add("toby", N, same(nov6$predict.loess(data$fit, data$nd, se = TRUE, cache = TRUE),
    e$predict.loess(data$fit, data$nd, se = TRUE)))
}
r <- do.call(rbind, rows); write.csv(r, out, row.names = FALSE)
cat("cases", nrow(r), "identical", sum(r$ok), "\n")
Rprof(NULL)
