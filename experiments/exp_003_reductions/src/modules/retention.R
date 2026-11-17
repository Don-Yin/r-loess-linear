# worker: Rscript <this file> <variant dir> <baseline dir> <reference dir> <output csv> <cap bytes> [profile path]
# Compare priority retention with the unmodified prototype and the Nov 6 reference.
args <- commandArgs(TRUE); out <- args[4]; cap <- as.numeric(args[5])
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "speed.R", "memory.R")) source(file.path(harness, file))
start_profile(args[6])
new <- load_loess(args[1], "loessfactorpredict.so"); base <- load_loess(args[2], "loessfactorpredict.so"); nov6 <- load_loess(args[3], "loesssent.so")
cases <- list(list(name = "regular", d = 3, n = 1024, m = 256, cell = .005, span = .25),
  list(name = "one-spike", d = 1, n = 1024, m = 128, cell = .2, span = .2),
  list(name = "one-spike", d = 1, n = 4096, m = 128, cell = .2, span = .2),
  list(name = "one-spike", d = 1, n = 8192, m = 128, cell = .2, span = .2),
  list(name = "two-spikes", d = 1, n = 4096, m = 128, cell = .2, span = .2))
rows <- list(); step <- progress(length(cases))
for (i in seq_along(cases)) {
  cs <- cases[[i]]; d <- cs$d; n <- cs$n; id <- paste(cs$name, n, cap, sep = "-"); step(i, id)
  set.seed(20261110)
  X <- switch(cs$name, regular = matrix(runif(n * d, -3, 3), n), `one-spike` = matrix(one_spike(n), n),
    `two-spikes` = matrix(c(rep(.5, floor(.4 * n)), rep(1, floor(.4 * n)), seq(1.2, 3, length.out = n - 2 * floor(.4 * n))), n))
  data <- capture(fit_data(X, cs$m, cs$span, cs$cell, rows = cs$name != "regular"))$value
  if (inherits(data, "error-message")) stop("fit failed for ", id, ": ", data)
  X <- data$X; y <- data$y; fit <- data$fit; nd <- data$nd
  pa <- capture(nov6$predict.loess(fit, nd, se = TRUE, cache = TRUE))
  pb <- capture(base$predict.loess(fit, nd, se = TRUE)); pc <- capture(new$predict.loess(fit, nd, se = TRUE))
  predict_case <- function(env, linear) if (cs$name == "regular") env$predict.loess(fit, nd, se = TRUE, cache = TRUE) else
    native_se(env, X, y, nd, cs, linear)
  a <- capture(predict_case(nov6, FALSE)); b <- capture(predict_case(base, TRUE)); c <- capture(predict_case(new, TRUE))
  ma <- capture(native_matrix(nov6, X, y, nd, cs, FALSE)); mb <- capture(native_matrix(base, X, y, nd, cs, TRUE))
  mc <- capture(native_matrix(new, X, y, nd, cs, TRUE))
  matrix_identical <- same(ma, mb) && same(mb, mc) && !inherits(ma$value, "error-message")
  identical_result <- same(pa, pb) && same(pb, pc) && same(a, b) && same(b, c) && !inherits(a$value, "error-message") && matrix_identical
  if (!identical_result) fail(id, out, public = list(pa, pb, pc), variance = list(a, b, c), matrix = list(ma, mb, mc))
  old <- probe_values(base); now <- probe_values(new)
  s <- interleaved_seconds(list(nov6 = function() predict_case(nov6, FALSE), baseline = function() predict_case(base, TRUE),
    variant = function() predict_case(new, TRUE)), 5L, batch = if (cs$name == "regular") 1L else if (n <= 1024) 20L else 5L)
  rows[[i]] <- data.frame(case = id, d, n, m = nrow(nd), cap_bytes = cap,
    identical = identical_result, matrix_identical, public_error = inherits(pa$value, "error-message"),
    nov6_s = s[["nov6"]], baseline_s = s[["baseline"]], variant_s = s[["variant"]],
    ratio_vs_baseline = s[["variant"]] / s[["baseline"]], ratio_vs_nov6 = s[["variant"]] / s[["nov6"]],
    baseline_native_bytes = old$native_bytes, variant_native_bytes = now$native_bytes,
    zero_radius_vertices = now$zero_radius_vertices, retained_vertices = now$retained_vertices, retained_bytes = now$retained_bytes,
    baseline_unretained_exceptional = old$unretained_exceptional_vertices, variant_unretained_exceptional = now$unretained_exceptional_vertices,
    baseline_replay_vertex_fits = old$replay_vertex_fits, variant_replay_vertex_fits = now$replay_vertex_fits)
  write.csv(do.call(rbind, rows), out, row.names = FALSE)
}
print(do.call(rbind, rows), row.names = FALSE)
Rprof(NULL)
