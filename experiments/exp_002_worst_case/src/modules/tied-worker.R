# worker: Rscript <this file> <experiment dir> <variant dir> <reference dir> <cap bytes> [profile path]
# Reuse shared exactness, loading, user-CPU timing, native variance and allocation accounting.
args <- commandArgs(TRUE)
root <- args[1]; cap <- as.numeric(args[4])
for (file in c("common.R", "variant.R", "speed.R", "memory.R", "tied.R")) source(file.path(root, "..", "..", "shared", "harness", file))
start_profile(args[5])
new <- load_loess(args[2], "loessfactorpredict.so")
nov6 <- load_loess(args[3], "loesssent.so")
out <- result_path(root, "tables", sprintf("tied-cap-%.0f.csv", cap))
results <- dirname(dirname(out))
dir.create(file.path(results, "diagnostics"), recursive = TRUE, showWarnings = FALSE)
cases <- measurement_cases()
if (cap == 0) {
  default <- read.csv(result_path(root, "tables", sprintf("tied-cap-%.0f.csv", MEASURED_CAP)))
  selected <- union(default$id[default$unretained_exceptional_vertices > 0], "spike-cloud-2-8192")
  cases <- cases[cases$id %in% selected, , drop = FALSE]
}
rows <- list(); step <- progress(nrow(cases))
for (i in seq_len(nrow(cases))) {
  cs <- cases[i, , drop = FALSE]; step(i, sprintf("%s cap=%.0f", cs$id, cap))
  rows[[i]] <- measure_case(cs, new, nov6, cap, results)
  write.csv(do.call(rbind, rows), out, row.names = FALSE)
  message(sprintf("saved %s: zero=%d unretained=%d replay=%d ratio=%.3f", cs$id,
    rows[[i]]$zero_radius_vertices, rows[[i]]$unretained_exceptional_vertices,
    rows[[i]]$replay_vertex_fits, rows[[i]]$ratio))
}
print(do.call(rbind, rows), row.names = FALSE)
Rprof(NULL)
