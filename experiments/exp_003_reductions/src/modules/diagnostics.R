# worker: Rscript <this file> <variant dir> <reference dir> <output csv> [profile path]
# Exercise the one-predictor diagnostic fallback directly; predict.loess removes outside points.
args <- commandArgs(TRUE)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "memory.R")) source(file.path(harness, file))
start_profile(args[4])
v <- c_routines(args[1], "loessfactorpredict.so"); r <- c_routines(args[2], "loesssent.so")
call_matrix <- function(entry, x, z, degree, cell)
  capture(native_call(entry, x, sin(x), z, .75, cell, degree, length(x) * length(z)))
rows <- list()
for (degree in 0:2) for (cell in c(0, .15)) {
  x <- seq(-1, 1, length.out = 96)
  z <- c(-1.5, .25, 1.5, -.3, -2)
  old <- call_matrix(r$C_loess_ise, x, z, degree, cell)
  new <- call_matrix(v$C_loess_factor_L, x, z, degree, cell)
  rows[[length(rows) + 1L]] <- data.frame(degree, cell,
    matrix_identical = same(old$value, new$value),
    warnings_identical = same(old$warnings, new$warnings), warnings = length(new$warnings),
    flagged_points = probe_values(v)$diagnostic_calls / length(x))
}
result <- do.call(rbind, rows)
write.csv(result, args[3], row.names = FALSE)
Rprof(NULL)
if (!all(result$matrix_identical & result$warnings_identical & result$flagged_points > 0)) {
  stop("one-predictor diagnostic checks failed: ", args[3])
}
