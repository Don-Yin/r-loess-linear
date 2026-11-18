# Speed: user CPU seconds of predict calls. Builds compared with each other run in alternating order
# over several rounds and each keeps its median, so drift on a shared machine reaches every build alike.
# source() after common.R; defines functions and the shared timing cases only.

user_seconds <- function(expr) { start <- proc.time(); force(expr); unname((proc.time() - start)[["user.self"]]) }

# Median seconds of each named call over `rounds`; `batch` repeats a call too short to time alone.
# The per-round seconds stay in attribute "rounds".
interleaved_seconds <- function(calls, rounds, batch = 1L) {
  seconds <- matrix(NA_real_, rounds, length(calls), dimnames = list(NULL, names(calls)))
  for (r in seq_len(rounds)) for (name in if (r %% 2L) names(calls) else rev(names(calls)))
    seconds[r, name] <- user_seconds(for (j in seq_len(batch)) capture(calls[[name]]())) / batch
  structure(apply(seconds, 2L, median), rounds = seconds)
}

# Per-round seconds already divide by the batch size used by the shared timing helper.

timing_rounds <- function(id, entry, seconds) {
  values <- attr(seconds, "rounds")
  data.frame(id, entry, round = rep(seq_len(nrow(values)), ncol(values)),
    implementation = rep(colnames(values), each = nrow(values)), user_s = as.vector(values))
}

# The nine timing cases (d, n, m, cell, span), named d<d>-n<n>-m<m>-cell<cell>, and the data of one of them.
timing_cases <- list(c(1, 20000, 80, 0.2, 0.5), c(1, 45000, 80, 0.2, 0.5), c(1, 2000, 2000, 0.05, 0.5),
  c(2, 2000, 80, 0.05, 0.75), c(3, 1024, 80, 0.05, 0.75), c(4, 256, 80, 0.05, 0.75),
  c(4, 512, 80, 0.05, 0.75), c(4, 1024, 80, 0.05, 0.75), c(4, 512, 512, 0.05, 0.75))
names(timing_cases) <- vapply(timing_cases, function(cs) sprintf("d%s-n%s-m%s-cell%s", cs[1], cs[2], cs[3], cs[4]), "")
timing_data <- function(cs) {
  set.seed(11)
  fit_data(matrix(runif(cs[2] * cs[1], -3, 3), cs[2]), cs[3], cs[5], cs[4])
}
