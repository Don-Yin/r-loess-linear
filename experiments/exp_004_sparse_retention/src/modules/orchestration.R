# Before is the package source (the patch of exp_003); after is variant.patch, the same with sparse slots.
measure <- function(root, profile = TRUE) {
  harness <- file.path(shared_dir(root), "harness")
  before_patch <- file.path(dirname(root), "exp_003_package_source", "variant.patch")
  summary <- run_variant(root, flags = "", profile = profile)
  before <- run_variant(root, flags = "", profile = profile, name = "before", patch = before_patch)

  # Small caps leave most vertices unretained, so slots are also taken over by zero-radius vertices.
  summary$cap_checks <- lapply(c(0, 4096, 65536), function(cap) {
    checked <- check_at_cap(root, cap, profile = profile); checked$dir <- NULL; checked
  })

  # Probes report bytes and vertex counts; they are compiled only into these measurement copies.
  probe <- vapply(list(before = "before", after = NULL), function(name) {
    work <- variant_work(root, name); dir <- file.path(work, "probe")
    copy_dir(file.path(work, "src"), dir)
    build(dir, "loessfactorpredict.so", paste(flags_at(MEASURED_CAP), "-DLOESS_TESTING"),
      result_path(root, "logs", "probe-build.log", name))
    dir
  }, "")
  reference <- file.path(variant_work(root), "reference-nov6")
  builds <- c(file.path(variant_work(root, "before"), "src"), file.path(variant_work(root), "src"))
  worker(root, file.path(root, "src", "modules", "pair-timing.R"),
    c(builds, probe, result_path(root, "tables", "timing-comparison.csv")), "pair-timing", profile)
  worker(root, file.path(harness, "tied-worker.R"),
    c(reference, root, sprintf("%.0f", MEASURED_CAP), paste0(names(probe), "=", probe)), "tied", profile)

  timing <- utils::read.csv(result_path(root, "tables", "timing-comparison.csv"))
  sides <- lapply(c(before = "before", after = "after"), function(label)
    utils::read.csv(result_path(root, "tables", sprintf("tied-%s-cap-%.0f.csv", label, MEASURED_CAP))))
  keys <- c("identical", "baseline_s", "ratio", "baseline_native_bytes", "retained_vertices", "replay_vertex_fits")
  tied <- sides$before[c("id", "d", "n", "neighborhood_rows", "needed_vertices", "nov6_s", "nov6_native_bytes")]
  for (label in names(sides)) {
    rows <- sides[[label]][match(tied$id, sides[[label]]$id), keys]
    tied[paste(label, keys, sep = "_")] <- rows
  }
  utils::write.csv(tied, result_path(root, "tables", "tied-comparison.csv"), row.names = FALSE)
  if (!all(timing$identical) || !all(tied$before_identical & tied$after_identical))
    stop("exactness failed in the before and after comparison: ", root, call. = FALSE)
  summary$before <- list(patch = before_patch, lines = before$lines, checks = before$checks)
  summary$against_before <- list(
    timing_cases = nrow(timing), tied_cases = nrow(tied),
    seconds_ratio_range = range(timing$after_s / timing$before_s),
    bytes_ratio_range = range(timing$after_native_bytes / timing$before_native_bytes),
    tied_seconds_ratio_range = range(tied$after_baseline_s / tied$before_baseline_s),
    tied_bytes_ratio_range = range(tied$after_baseline_native_bytes / tied$before_baseline_native_bytes),
    tied_slower_than_nov6 = list(before = sum(tied$before_ratio > 1), after = sum(tied$after_ratio > 1)),
    tied_all_vertices_retained = list(before = sum(tied$before_retained_vertices == tied$needed_vertices),
      after = sum(tied$after_retained_vertices == tied$needed_vertices)))
  write_json(summary, result_path(root, "json", "summary.json"))
  message(sprintf("against the package source: seconds %.2f to %.2f, bytes %.2f to %.2f in %d timing cases; tied cases slower than Nov 6: %d before, %d after",
    summary$against_before$seconds_ratio_range[1], summary$against_before$seconds_ratio_range[2],
    summary$against_before$bytes_ratio_range[1], summary$against_before$bytes_ratio_range[2], nrow(timing),
    summary$against_before$tied_slower_than_nov6$before, summary$against_before$tied_slower_than_nov6$after))
  summary
}
