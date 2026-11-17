# worker: Rscript <this file> <variant dir> <original R dir> <output csv> <cache|actual-vertices> [profile path]
# The common timing cases, each compared only with original R; bytes follow the allocation formulas.

args <- commandArgs(TRUE); dir <- args[1]; ref <- args[2]; out <- args[3]; kind <- args[4]
if (!kind %in% c("cache", "actual-vertices")) stop("unknown matrix variant: ", kind)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- dirname(normalizePath(gsub("~+~", " ", self, fixed = TRUE)))
for (file in c("common.R", "speed.R", "memory.R")) source(file.path(harness, file))
start_profile(args[5])
new <- load_loess(dir, "loessfactorpredict.so"); original <- load_loess(ref, "loesssent.so")
step <- progress(length(timing_cases))
rows <- lapply(seq_along(timing_cases), function(i) {
  case <- names(timing_cases)[i]; step(i, case); cs <- timing_cases[[i]]
  d <- cs[1]; n <- cs[2]; m <- cs[3]; data <- timing_data(cs)
  calls <- list(original = function() original$predict.loess(data$fit, data$nd, se = TRUE),
    variant = function() new$predict.loess(data$fit, data$nd, se = TRUE))
  a <- capture(calls$original()); b <- capture(calls$variant())
  exact <- same(a, b) && !inherits(a$value, "error-message")
  if (!exact) fail(case, out, original = a, variant = b)
  nv <- unname(data$fit$kd$parameter["nv"])
  rbytes <- reference_bytes(d, n, m, cs[5], 2, 0)
  bytes <- reference_bytes(d, n, m, cs[5], 2, nv,
    coefficient_vertices = if (kind == "actual-vertices") nv else max(200, n))
  rounds <- if (n > 5000) 5L else 9L
  seconds <- interleaved_seconds(calls, rounds)
  data.frame(case, d, n, m, cell = cs[4], span = cs[5], vertices = nv, rounds,
    r_s = seconds[["original"]], variant_s = seconds[["variant"]], ratio = seconds[["variant"]] / seconds[["original"]],
    r_native_bytes = rbytes[["native"]], native_bytes = bytes[["native"]],
    r_L_bytes = rbytes[["L"]], L_bytes = bytes[["L"]], identical = exact, load1 = load1())
})
r <- do.call(rbind, rows); write.csv(r, out, row.names = FALSE); print(r, row.names = FALSE)
Rprof(NULL)
