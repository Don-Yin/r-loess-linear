# worker: Rscript <this file> <priority dir> <stack dir> <reference dir> <experiment dir> <cap bytes> <profile path>
# The tied cases and their measurement come from shared/harness/tied.R without changed inputs or arithmetic.
args <- commandArgs(TRUE)
if (length(args) != 6L) stop("expected six worker arguments, got ", length(args), call. = FALSE)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "variant.R", "speed.R", "memory.R", "tied.R")) source(file.path(harness, file))
start_profile(args[6])
root <- args[4]; cap <- as.numeric(args[5])
nov6 <- load_loess(args[3], "loesssent.so")
labels <- if (cap == 0) "stack" else c("stack", "priority")
dirs <- list(stack = args[2], priority = args[1])
builds <- lapply(dirs[labels], load_loess, so = "loessfactorpredict.so")
cases <- measurement_cases()
table <- function(label, value = cap) result_path(root, "tables", paste0("tied-", label, "-cap-", value, ".csv"))
if (cap == 0) {
  selected <- "spike-cloud-2-8192"
  for (label in c("stack", "priority")) {
    default <- read.csv(table(label, MEASURED_CAP))
    selected <- union(selected, default$id[default$unretained_exceptional_vertices > 0])
  }
  cases <- cases[cases$id %in% selected, , drop = FALSE]
}
rows <- setNames(lapply(labels, function(label) list()), labels)
results <- setNames(lapply(labels, function(label) {
  diagnostics <- result_path(root, file.path("variants", label), "diagnostics")
  dir.create(diagnostics, recursive = TRUE, showWarnings = FALSE)
  dirname(diagnostics)
}), labels)
step <- progress(nrow(cases))
for (i in seq_len(nrow(cases))) {
  cs <- cases[i, , drop = FALSE]; step(i, sprintf("%s cap=%.0f", cs$id, cap))
  for (label in if (i %% 2L) labels else rev(labels)) {
    rows[[label]][[i]] <- measure_case(cs, builds[[label]], nov6, cap, results[[label]])
    write.csv(do.call(rbind, rows[[label]]), table(label), row.names = FALSE)
    row <- rows[[label]][[i]]
    message(sprintf("saved %s %s: zero=%d unretained=%d replay=%d ratio=%.3f", cs$id, label,
      row$zero_radius_vertices, row$unretained_exceptional_vertices, row$replay_vertex_fits, row$ratio))
  }
}
Rprof(NULL)
if (!is.na(args[6]) && nzchar(args[6])) saveRDS(summaryRprof(args[6]), paste0(args[6], "-summary.rds"))
