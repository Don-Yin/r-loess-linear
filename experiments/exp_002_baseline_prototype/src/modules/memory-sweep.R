# worker: Rscript <this file> <variant dir> <output csv> [profile path]
# Native bytes of one predict(se = TRUE) call over N in Toby's setup, against the workspace R's predict
# requests. The sweep includes the last N at which R runs and the first at which it stops.
args <- commandArgs(TRUE); dir <- args[1]; out <- args[2]
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "memory.R")) source(file.path(harness, file))
start_profile(args[3])
new <- load_loess(dir, "loessfactorpredict.so")
r_stops <- reference_first_invalid_n(1, 0.5, 2)
ns <- sort(c(500, 1000, 2000, 5000, 10000, 20000, 30000, 40000, 45000, r_stops - 1, r_stops, 60000, 100000, 200000))
step <- progress(length(ns))
rows <- lapply(seq_along(ns), function(i) {
  n <- ns[i]; step(i, sprintf("N = %.0f", n)); data <- toby_data(n)
  b <- new$predict.loess(data$fit, data$nd, se = TRUE)

  # R's predict is compared where it runs in a few seconds.
  same_as_r <- if (n <= 20000) same(stats::predict(data$fit, data$nd, se = TRUE), b) else NA

  # nv = 0: R's C workspace alone, without the N by nv cache that only the Nov 6 patch adds.
  data.frame(n, r_runs = n < r_stops, r_workspace_bytes = reference_bytes(1, n, 80, 0.5, 2, 0)[["native"]],
    native_bytes = probe_values(new)$native_bytes, identical_to_r = same_as_r)
})
r <- do.call(rbind, rows); write.csv(r, out, row.names = FALSE); print(r, row.names = FALSE)
if (any(r$identical_to_r %in% FALSE)) stop("prediction differs from R; see ", out)
Rprof(NULL)
