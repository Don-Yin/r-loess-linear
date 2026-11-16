# worker: Rscript <this file> <variant dir> <reference dir> <output csv> [profile path]
# The nine timing cases: user CPU of predict(se = TRUE) for a build against the Nov 6 patch (speed.R), and
# the bytes each requests (memory.R).
args <- commandArgs(TRUE); dir <- args[1]; ref <- args[2]; out <- args[3]
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- dirname(normalizePath(gsub("~+~", " ", self, fixed = TRUE)))
for (file in c("common.R", "speed.R", "memory.R")) source(file.path(harness, file))
start_profile(args[4])
new <- load_loess(dir, "loessfactorpredict.so"); nov6 <- load_loess(ref, "loesssent.so")
step <- progress(length(timing_cases))
rows <- lapply(seq_along(timing_cases), function(i) {
  case <- names(timing_cases)[i]; step(i, case); cs <- timing_cases[[i]]; d <- cs[1]; n <- cs[2]; m <- cs[3]; data <- timing_data(cs)
  calls <- list(nov6 = function() nov6$predict.loess(data$fit, data$nd, se = TRUE, cache = TRUE),
    variant = function() new$predict.loess(data$fit, data$nd, se = TRUE))
  a <- capture(calls$nov6()); identical_out <- same(a, capture(calls$variant())) && !inherits(a$value, "error-message")
  p <- probe_values(new); nv <- unname(data$fit$kd$parameter["nv"])
  if (!is.na(p$vertices) && p$vertices != nv) stop("probe vertex count ", p$vertices, " differs from the fit's ", nv)
  bytes <- reference_bytes(d, n, m, cs[5], 2, nv)
  s <- interleaved_seconds(calls, if (n > 5000) 5L else 9L)
  data.frame(case, d, n, m, cell = cs[4], nov6_s = s[["nov6"]], variant_s = s[["variant"]],
    ratio = s[["variant"]] / s[["nov6"]], native_bytes = p$native_bytes, nov6_native_bytes = bytes[["native"]],
    nov6_L_bytes = bytes[["L"]], identical = identical_out, load1 = load1())
})
r <- do.call(rbind, rows); write.csv(r, out, row.names = FALSE); print(r, row.names = FALSE)
Rprof(NULL)
