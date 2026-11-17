# Helpers shared by the harness workers and by experiment code: loading builds, capturing output, exact
# comparison, test inputs, the native entry. Speed is measured in speed.R and memory in memory.R.
# source() this file; it defines functions only.

# The .C routines of one built library, named C_<routine> as R's own namespace names them.
c_routines <- function(dir, so) {
  routines <- getDLLRegisteredRoutines(dyn.load(file.path(dir, so)))$.C
  stats::setNames(routines, paste0("C_", names(routines)))
}

# Load one built library with its own loess.R, so two builds can be called side by side in one session.
load_loess <- function(dir, so) {
  env <- list2env(c_routines(dir, so), parent = asNamespace("stats"))
  sys.source(file.path(dir, "loess.R"), env)
  env
}

# Value plus warning texts in order; an error becomes its message with class "error-message".
capture <- function(expr) {
  warnings <- character()
  value <- withCallingHandlers(
    tryCatch(expr, error = function(e) structure(conditionMessage(e), class = "error-message")),
    warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") })
  list(value = value, warnings = warnings)
}

# Bit for bit: NaN payloads and the two kinds of NA are not treated as equal.
same <- function(a, b) identical(a, b, num.eq = FALSE, single.NA = FALSE)

# Stop a worker whose comparison failed, after saving every compared value next to its output table.
fail <- function(id, out, ...) {
  path <- sub("\\.csv$", paste0("-", id, "-failure.rds"), out); saveRDS(list(...), path)
  stop("not identical or an error: ", id, "; the compared values are in ", path, call. = FALSE)
}

# One minute load average, read from uptime so it works on macOS and Linux.
load1 <- function() as.numeric(sub(",", ".", sub(".*load averages?: *([0-9]+[.,][0-9]+).*", "\\1", system("uptime", intern = TRUE))))

# Progress in the manner of tqdm, one line per step so that it reads the same on a terminal, in a log and in
# a notebook: "[3/8] |======                  | label, 01:10 elapsed, about 02:55 left". Call the returned
# function before step i.
progress <- function(n, width = 24L) {
  start <- Sys.time(); clock <- function(s) sprintf("%02d:%02d", as.integer(s) %/% 60L, as.integer(s) %% 60L)
  function(i, label = "") {
    elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs")); done <- (i - 1L) * width %/% n
    left <- if (i > 1L) paste(", about", clock(elapsed / (i - 1) * (n - i + 1)), "left") else ""
    cat(sprintf("[%d/%d] |%s%s| %s, %s elapsed%s\n", i, n, strrep("=", done), strrep(" ", width - done),
      label, clock(elapsed), left))
    flush(stdout())
  }
}

# Start Rprof when a worker was given a profile path as its last argument; "" or missing means no profile.
start_profile <- function(path) if (!is.na(path) && nzchar(path)) Rprof(path)

write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
}

# Response, R's own fit and prediction points for the predictor matrix X: m points uniform on (-2.5, 2.5),
# or with rows = TRUE m evenly spaced rows of X. Draws from the current random stream, so the caller sets
# the seed.
fit_data <- function(X, m, span, cell, rows = FALSE) {
  n <- nrow(X); d <- ncol(X); colnames(X) <- paste0("x", seq_len(d))
  df <- data.frame(X, y = rowSums(sin(X)) + rnorm(n, sd = .35))
  fit <- stats::loess(reformulate(colnames(X), response = "y"), df, span = span, control = loess.control(cell = cell))
  nd <- if (rows) X[unique(round(seq(1, n, length.out = m))), , drop = FALSE] else
    matrix(runif(m * d, -2.5, 2.5), m, dimnames = list(NULL, colnames(X)))
  list(X = X, y = df$y, fit = fit, nd = as.data.frame(nd))
}

# Half of the n values tied at 0.5, the rest spread over (1, 3): a neighbourhood of radius zero at the spike.
one_spike <- function(n) c(rep(.5, n / 2), seq(1, 3, length.out = n / 2))

# Toby Dylan Hocking's setup, https://github.com/tdhock/atime/issues/135:
# one predictor, span 0.5, 80 prediction points across the range of x.
toby_data <- function(n) {
  set.seed(20261105); x <- runif(n, -3, 3); y <- sin(x) + rnorm(n, sd = 0.35)
  list(fit = stats::loess(y ~ x, span = 0.5), nd = data.frame(x = seq(min(x), max(x), length.out = 80L)))
}

# One raw call of a native standard-error entry with unit weights; fc is span * cell, as predict.loess
# passes it, and size the length of the output the entry fills.
native_call <- function(entry, X, y, nd, span, fc, degree, size) {
  X <- as.matrix(X); nd <- as.matrix(nd); n <- nrow(X); d <- ncol(X); m <- nrow(nd)
  .C(entry, as.double(y), as.double(X), as.double(nd), rep(1, n), as.double(span), as.integer(degree),
    as.integer(d), rep(2L, d), 0L, as.double(fc), as.integer(d), as.integer(n), as.integer(m), double(m),
    output = double(size), 1L)$output
}

# Variances from the native entry. Needed when a zero-radius fitted surface makes the public predict stop
# before it reaches that entry. linear = TRUE for builds that return variances, FALSE for the reference,
# which returns the N by M operator matrix.
native_se <- function(env, X, y, nd, cs, linear) {
  n <- nrow(X); m <- nrow(nd)
  result <- native_call(env$C_loess_ise, X, y, nd, cs$span, cs$span * cs$cell, 2L, if (linear) m else n * m)
  if (linear) result else rowSums(matrix(result^2, m, n))
}

# The same variances from unpatched R's own entry, which takes one argument fewer than the builds'.
r_native_se <- function(X, y, nd, cs) {
  X <- as.matrix(X); nd <- as.matrix(nd); n <- nrow(X); d <- ncol(X); m <- nrow(nd)
  L <- .C(stats:::C_loess_ise, as.double(y), as.double(X), as.double(nd), rep(1, n), as.double(cs$span), 2L,
    as.integer(d), rep(2L, d), 0L, as.double(cs$span * cs$cell), as.integer(d), as.integer(n), as.integer(m),
    double(m), L = double(n * m))$L
  rowSums(matrix(L^2, m, n))
}

# The N by M operator matrix itself: from the test entry of a linear build, or from the reference.
native_matrix <- function(env, X, y, nd, cs, linear)
  native_call(if (linear) env$C_loess_factor_L else env$C_loess_ise, X, y, nd, cs$span, cs$span * cs$cell, 2L,
    nrow(X) * nrow(nd))
