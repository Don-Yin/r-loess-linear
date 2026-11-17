# worker: Rscript <this file> <tests|timing|memory|additions> <experiment dir> <installed library> <label> <profile path>

main <- function(operation, root, library, label, profile) {
  project <- dirname(dirname(root))
  for (file in c("common.R", "variant.R")) source(file.path(project, "shared", "harness", file))
  source(file.path(root, "src", "utils", "packages.R"))
  start_profile(profile)
  on.exit(Rprof(NULL), add = TRUE)
  if (operation == "tests") {
    .libPaths(c(library, .libPaths()))
    env <- new.env(parent = globalenv())
    sys.source(file.path(project, "tests", "predict-se.R"), env)
    if (env$checks != 324L) stop("package test comparisons: expected 324, got ", env$checks)
    entries <- names(getDLLRegisteredRoutines(getNamespaceInfo(asNamespace("loesslin"), "DLLs")[["loesslin"]])$.C)
    write_json(list(comparisons = env$checks, invalid_object_comparisons = 1L,
      fit_errors = env$fit_errors, local_fit_registered = "loess_raw" %in% entries,
      registered_entries = entries), result_path(root, "json", paste0("tests-", label, ".json")))
  } else if (operation %in% c("timing", "memory", "additions")) {
    for (file in c("speed.R", "memory.R", "tied.R")) source(file.path(project, "shared", "harness", file))
    source(file.path(root, "src", "modules", "measurement.R"))
    if (operation != "timing") source(file.path(root, "src/modules", paste0(operation, ".R")))
    switch(operation, timing = measure_timing(root), memory = measure_memory(root), additions = measure_additions(root))
  } else stop("unknown worker operation: ", operation)
}

# Sourcing the worker defines its entry without loading a package or starting a profile.

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 5L) stop("expected operation, experiment dir, library, label and profile path; got ", length(args))
  invisible(main(args[1L], args[2L], args[3L], args[4L], args[5L]))
}
