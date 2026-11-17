# worker: Rscript <this file> <output csv> [profile path]
# User CPU of R's own predict(se = TRUE), unpatched, in the nine timing cases, with the workspace R requests.
args <- commandArgs(TRUE); out <- args[1]
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "speed.R", "memory.R")) source(file.path(harness, file))
start_profile(args[2])
step <- progress(length(timing_cases))
rows <- lapply(seq_along(timing_cases), function(i) {
  case <- names(timing_cases)[i]; cs <- timing_cases[[i]]; step(i, case); data <- timing_data(cs)
  r_s <- interleaved_seconds(list(r = function() stats::predict(data$fit, data$nd, se = TRUE)), 3L)[["r"]]

  # nv = 0: R's C workspace alone, without the N by nv cache that only the Nov 6 patch adds.
  data.frame(case, d = cs[1], n = cs[2], m = cs[3], cell = cs[4], r_s,
    r_workspace_bytes = reference_bytes(cs[1], cs[2], cs[3], cs[5], 2, 0)[["native"]], load1 = load1())
})
r <- do.call(rbind, rows); write.csv(r, out, row.names = FALSE); print(r, row.names = FALSE)
Rprof(NULL)
