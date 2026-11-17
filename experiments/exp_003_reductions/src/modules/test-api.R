# worker: Rscript <this file> <production dir> <testing dir> <baseline dir> <output json> [profile path]
args <- commandArgs(TRUE)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
source(file.path(harness, "common.R"))
start_profile(args[5])
routines <- lapply(args[1:3], c_routines, so = "loessfactorpredict.so")
production <- routines[[1]]; testing <- routines[[2]]; baseline <- routines[[3]]
probes <- c(C_loess_probe = 20L, C_loess_block_probe = 2L, C_loess_geometry_probe = 2L,
  C_loess_retention_probe = 4L, C_loess_exception_probe = 3L)
test_names <- c("C_loess_factor_L", names(probes))
stopifnot(length(production) == 5L, length(testing) == 11L,
  !any(test_names %in% names(production)), all(test_names %in% names(testing)))
rows <- list()
add <- function(id, ok) rows[[length(rows) + 1L]] <<- data.frame(id, ok)
set.seed(903)
for (d in 1:4) for (degree in 0:2) for (kind in c("dense", "ties")) {
  n <- 150L; m <- 12L
  x <- matrix(runif(n * d, -3, 3), n, d)
  if (kind == "ties") x[1:120, ] <- 0
  z <- x[seq_len(m), , drop = FALSE]
  y <- rowSums(sin(x)); weights <- runif(n, 0.5, 2)
  input <- list(as.double(y), as.double(x), as.double(z), weights, 0.75,
    as.integer(degree), as.integer(d), rep(2L, d), 0L, 0.15,
    as.integer(d), n, m, double(m), L = double(n * m), 1L)
  a <- capture(do.call(.C, c(list(baseline$C_loess_factor_L), input)))
  b <- capture(do.call(.C, c(list(testing$C_loess_factor_L), input)))
  id <- paste(d, degree, kind, sep = "-")
  if (inherits(a$value, "error-message") || inherits(b$value, "error-message")) {
    stop("full operator-matrix call failed for ", id, "; baseline: ", paste(a$value, collapse = " "),
      "; testing: ", paste(b$value, collapse = " "), call. = FALSE)
  }
  add(paste(id, "full-L", sep = "-"), same(a, b))
  for (name in names(probes)) {
    pa <- .C(baseline[[name]], out = double(probes[[name]]))$out
    pb <- .C(testing[[name]], out = double(probes[[name]]))$out
    add(paste(id, name, sep = "-"), same(pa, pb))
  }
}
r <- do.call(rbind, rows)
write_json(list(cases = nrow(r), identical = sum(r$ok),
  production_entries = length(production), testing_entries = length(testing)), args[4])
print(r, row.names = FALSE)
Rprof(NULL)
if (!all(r$ok)) stop("test-only full L or a probe differs from the baseline: ", args[4])
