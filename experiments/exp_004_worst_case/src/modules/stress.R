# worker: Rscript <this file> <variant dir> <reference dir> <output csv> <cap bytes> [profile path]
# Many vertex fits redone (over-cap) and a zero-radius vertex, at one retention cap. Exactness precedes every timing.
args <- commandArgs(TRUE); dir <- args[1]; ref <- args[2]; out <- args[3]; cap <- as.numeric(args[4])
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "speed.R", "memory.R")) source(file.path(harness, file))
start_profile(args[5])
new <- load_loess(dir, "loessfactorpredict.so"); nov6 <- load_loess(ref, "loesssent.so")
cases <- list()
if (cap != 65536) for (d in 3:4) for (n in c(1024, 4096)) {
  cases[[length(cases) + 1]] <- list(suite = "over-cap", d = d, n = n, m = n, cell = .005, span = .25)
}
if (cap != 1048576) for (n in c(1024, 4096, 8192)) {
  cases[[length(cases) + 1]] <- list(suite = "zero-radius", d = 1, n = n, m = 128, cell = .2, span = .2)
}
rows <- raw <- list(); step <- progress(length(cases))
for (i in seq_along(cases)) {
  cs <- cases[[i]]; d <- cs$d; n <- cs$n; tied <- cs$suite == "zero-radius"
  id <- paste(cs$suite, d, n, cs$m, cap, sep = "-"); step(i, id)
  set.seed(20261110)
  data <- capture(fit_data(if (tied) matrix(one_spike(n), n) else matrix(runif(n * d, -3, 3), n),
    cs$m, cs$span, cs$cell, rows = tied))$value
  if (inherits(data, "error-message")) stop("fit failed for ", id, ": ", data)
  X <- data$X; y <- data$y; fit <- data$fit; nd <- data$nd
  public_a <- capture(nov6$predict.loess(fit, nd, se = TRUE, cache = TRUE))
  public_b <- capture(new$predict.loess(fit, nd, se = TRUE))
  predict_a <- if (tied) function() native_se(nov6, X, y, nd, cs, FALSE) else
    function() nov6$predict.loess(fit, nd, se = TRUE, cache = TRUE)
  predict_b <- if (tied) function() native_se(new, X, y, nd, cs, TRUE) else
    function() new$predict.loess(fit, nd, se = TRUE)
  a <- capture(predict_a()); b <- capture(predict_b())
  identical_out <- same(public_a, public_b) && same(a, b)
  if (!identical_out || inherits(a$value, "error-message")) fail(id, out, public = list(public_a, public_b), variance = list(a, b))
  p <- probe_values(new)
  bytes <- reference_bytes(d, n, nrow(nd), cs$span, 2, p$vertices)
  s <- interleaved_seconds(list(nov6 = predict_a, baseline = predict_b), 3L,
    batch = if (!tied) 1L else if (n <= 1024) 20L else 5L)
  raw[[i]] <- timing_rounds(id, if (tied) "native" else "public", s)
  rows[[i]] <- data.frame(id, suite = cs$suite, cap_bytes = cap, d, n, m = nrow(nd), cell = cs$cell,
    span = cs$span, identical = identical_out, public_error = inherits(public_a$value, "error-message"),
    warning_count = length(a$warnings), nov6_s = s[["nov6"]], baseline_s = s[["baseline"]],
    ratio = s[["baseline"]] / s[["nov6"]], baseline_native_bytes = p$native_bytes, nov6_native_bytes = bytes[["native"]],
    nov6_L_bytes = bytes[["L"]], nov6_native_and_L_bytes = sum(bytes), vertices = p$vertices,
    needed_vertices = p$needed_vertices, p[c("retained_vertices", "retained_bytes", "zero_radius_vertices",
      "unretained_exceptional_vertices", "replay_vertex_fits")])
  write.csv(do.call(rbind, rows), out, row.names = FALSE)
  write.csv(do.call(rbind, raw), sub("[.]csv$", "-rounds.csv", out), row.names = FALSE)
}
print(do.call(rbind, rows), row.names = FALSE)
Rprof(NULL)
