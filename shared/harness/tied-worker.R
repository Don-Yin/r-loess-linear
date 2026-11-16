# worker: Rscript <this file> <reference dir> <experiment dir> <cap bytes> <label>=<probe build dir> ... [profile path]
# Every tied case of tied.R on each labelled build, in alternating order; writes
# <experiment>/.results/tables/tied-<label>-cap-<cap>.csv after every case.
args <- commandArgs(TRUE)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- dirname(normalizePath(gsub("~+~", " ", self, fixed = TRUE)))
for (file in c("common.R", "variant.R", "speed.R", "memory.R", "tied.R")) source(file.path(harness, file))
pairs <- grep("=", args[-(1:3)], value = TRUE, fixed = TRUE)
start_profile(setdiff(args[-(1:3)], pairs)[1])
root <- args[2]; cap <- as.numeric(args[3])
nov6 <- load_loess(args[1], "loesssent.so")
dirs <- setNames(sub("^[^=]*=", "", pairs), sub("=.*$", "", pairs)); labels <- names(dirs)
builds <- lapply(dirs, load_loess, so = "loessfactorpredict.so")
results <- lapply(setNames(labels, labels), function(label) {
  diagnostics <- result_path(root, file.path("variants", label), "diagnostics")
  dir.create(diagnostics, recursive = TRUE, showWarnings = FALSE)
  dirname(diagnostics)
})
cases <- measurement_cases(); rows <- lapply(results, function(label) list())
step <- progress(nrow(cases))
for (i in seq_len(nrow(cases))) {
  cs <- cases[i, , drop = FALSE]; step(i, cs$id)
  for (label in if (i %% 2L) labels else rev(labels)) {
    row <- measure_case(cs, builds[[label]], nov6, cap, results[[label]])

    # measure_case counts slots for whole-row retention; the build's own count is retained_vertices.
    row$retention_slots <- NULL
    rows[[label]][[i]] <- row
    write.csv(do.call(rbind, rows[[label]]), result_path(root, "tables", sprintf("tied-%s-cap-%.0f.csv", label, cap)), row.names = FALSE)
  }
}
Rprof(NULL)
