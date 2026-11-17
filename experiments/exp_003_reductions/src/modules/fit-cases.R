# worker: Rscript <this file> <variant dir> <fit output json> <replay dir> <replay output json> [profile path]
args <- commandArgs(TRUE)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "memory.R")) source(file.path(harness, file))
start_profile(args[5])
e <- load_loess(args[1], "loessfactorpredict.so")
rows <- list()
set.seed(907)
for (d in 1:4) for (degree in 0:2) for (family in c("gaussian", "symmetric"))
  for (surface in c("direct", "interpolate")) for (statistics in c("approximate", "exact"))
    for (kind in c("dense", "ties")) {
      n <- 120L; x <- matrix(rnorm(n * d), n, d); colnames(x) <- paste0("x", seq_len(d))
      if (kind == "ties") x <- round(x)
      data <- data.frame(x, y = rowSums(sin(x)) + rnorm(n, sd = 0.3), w = runif(n, 0.5, 2))
      formula <- reformulate(colnames(x), response = "y")
      control <- loess.control(surface = surface, statistics = statistics, cell = 0.1)
      a <- capture(stats::loess(formula, data, weights = w, span = 0.9, degree = degree, family = family, control = control))
      b <- capture(e$loess(formula, data, weights = w, span = 0.9, degree = degree, family = family, control = control))
      if (!inherits(a$value, "error-message")) a$value$call <- NULL
      if (!inherits(b$value, "error-message")) b$value$call <- NULL
      rows[[length(rows) + 1L]] <- data.frame(id = paste(d, degree, family, surface, statistics, kind, sep = "-"), ok = same(a, b))
    }
r <- do.call(rbind, rows)
write_json(list(cases = nrow(r), identical = sum(r$ok)), args[2])
print(r, row.names = FALSE)
if (!all(r$ok)) stop("complete fitted model or its diagnostics changed")

# With no retained vertices, these tied inputs must reach silent replay.
replay <- load_loess(args[3], "loessfactorpredict.so"); rows <- list(); exceptional <- numeric()
set.seed(1707)
for (kind in c("two-values", "block-ties")) for (d in 1:2) for (degree in 0:2) for (span in c(0.2, 0.6)) {
  n <- 300L
  x <- if (kind == "two-values") sample(c(0, 1), n, TRUE) else c(rep(0, 200), runif(100, 1, 2))
  data <- data.frame(x1 = x, y = sin(x) + rnorm(n, sd = 0.3))
  if (d == 2L) data$x2 <- if (kind == "two-values") sample(c(0, 1), n, TRUE) else round(runif(n, 0, 2))
  formula <- if (d == 1L) y ~ x1 else y ~ x1 + x2
  fit <- capture(stats::loess(formula, data, degree = degree, span = span, control = loess.control(cell = 0)))
  if (inherits(fit$value, "error-message")) next
  nd <- data[, setdiff(names(data), "y"), drop = FALSE]
  a <- capture(stats::predict(fit$value, nd, se = TRUE))
  b <- capture(replay$predict.loess(fit$value, nd, se = TRUE))
  lost <- probe_values(replay)$unretained_exceptional_vertices; exceptional <- c(exceptional, lost)
  rows[[length(rows) + 1L]] <- data.frame(id = paste(kind, d, degree, span, sep = "-"), ok = same(a, b), exceptional = lost)
}
r <- do.call(rbind, rows)
write_json(list(cases = nrow(r), identical = sum(r$ok), cases_with_exceptional_replay = sum(exceptional > 0),
  maximum_exceptional_vertices = max(exceptional)), args[4])
print(r, row.names = FALSE)
if (!all(r$ok) || !any(exceptional > 0)) stop("silent exceptional replay differs or was not reached: ", args[4])
Rprof(NULL)
