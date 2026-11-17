# Print source, standalone build-adapter and total line changes against original R for each build.

main <- function(root) {
  for (file in c("common.R", "variant.R")) source(file.path(root, "shared", "harness", file))
  experiments <- file.path(root, "experiments")
  builds <- list(
    exp_000_nov6_cache = list(cache = ""),
    exp_001_actual_vertices = list(actual_vertices = "variant.patch"),
    exp_002_baseline_prototype = list(prototype = ""),
    exp_003_reductions = as.list(stats::setNames(
      list.files(file.path(experiments, "exp_003_reductions", "patches"), "\\.patch$"),
      sub("\\.patch$", "", list.files(file.path(experiments, "exp_003_reductions", "patches"), "\\.patch$")))),
    exp_004_worst_case = list(prototype = ""),
    exp_005_package_source = list(package = "variant.patch", stack = "patches/stack.patch"),
    exp_006_sparse_retention = list(sparse = "variant.patch", before = "../exp_005_package_source/variant.patch"))
  rows <- list()
  for (experiment in names(builds)) for (name in names(builds[[experiment]])) {
    exp_dir <- file.path(experiments, experiment); patch <- builds[[experiment]][[name]]
    if (experiment == "exp_003_reductions") patch <- file.path("patches", patch)
    if (nzchar(patch)) {
      patch <- file.path(exp_dir, patch)
      if (!file.exists(patch)) stop("missing patch for ", experiment, "/", name, ": ", patch)
    }
    base <- if (experiment %in% c("exp_000_nov6_cache", "exp_001_actual_vertices")) "reference-nov6" else "baseline"
    dir <- file.path(variant_work(exp_dir), "line-count", name)
    prepare_variant(exp_dir, dir, base, patch, result_path(exp_dir, "logs", paste0("line-count-", name, ".log")))
    lines <- line_count(dir, file.path(root, "shared", "reference-r"))
    adapter <- lines$files[["register.c"]]
    if (is.null(adapter)) adapter <- list(added = 0, removed = 0)
    for (part in c("source", "register.c", "total")) {
      counts <- switch(part, source = c(lines$added - adapter$added, lines$removed - adapter$removed),
        register.c = c(adapter$added, adapter$removed), total = c(lines$added, lines$removed))
      rows[[length(rows) + 1L]] <- data.frame(experiment, variant = name, part, added = counts[1], removed = counts[2])
    }
  }
  rows <- do.call(rbind, rows)
  for (experiment in names(builds)) utils::write.csv(rows[rows$experiment == experiment, ],
    result_path(file.path(experiments, experiment), "tables", "lines-against-r.csv"), row.names = FALSE)
  utils::write.csv(rows, stdout(), row.names = FALSE)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(TRUE)
  if (length(args)) stop("unknown argument: ", paste(args, collapse = " "))
  file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
  root <- dirname(dirname(dirname(normalizePath(gsub("~+~", " ", file, fixed = TRUE)))))
  main(root)
}
