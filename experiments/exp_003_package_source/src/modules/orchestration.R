# Keep production checks uninstrumented and enable probes only in measurement copies.
measure <- function(root, profile = TRUE) {
  harness <- file.path(shared_dir(root), "harness")
  source(file.path(harness, "tied.R"), local = TRUE)
  summary <- run_variant(root, flags = "", profile = profile)
  control_checks <- check_at_cap(root, 0, profile = profile)

  # The plain stack exists only as the requested before side, not as another package source.
  stack_summary <- run_variant(root, flags = "", profile = profile, name = "stack")
  stack_control_checks <- check_at_cap(root, 0, profile = profile, name = "stack")
  shared_timing <- compare_shared_timing(summary, stack_summary)
  utils::write.csv(shared_timing, result_path(root, "tables", "shared-timing-comparison.csv"), row.names = FALSE)

  reference <- file.path(variant_work(root), "reference-nov6")
  measured <- list()
  caps <- c(MEASURED_CAP, 0); step <- progress(length(caps))
  for (i in seq_along(caps)) {
    cap <- caps[i]; dirs <- list(); step(i, sprintf("tied comparison at cap %.0f bytes", cap))
    for (label in if (cap == 0) "stack" else c("stack", "priority")) {
      name <- if (label == "stack") "stack" else NULL
      work <- variant_work(root, name)
      dir <- file.path(work, sprintf("probe-cap-%.0f", cap)); dirs[[label]] <- dir
      copy_dir(file.path(work, "src"), dir)
      build(dir, "loessfactorpredict.so", paste(flags_at(cap), "-DLOESS_TESTING"),
        result_path(root, "logs", sprintf("probe-build-cap-%.0f.log", cap), name))
    }
    worker(root, file.path(root, "src", "modules", "tied-worker.R"),
      c(if (cap == 0) control_checks$dir else dirs$priority, dirs$stack, reference, root, as.character(cap)),
      sprintf("tied-cap-%.0f", cap), profile)
    for (label in names(dirs)) {
      rows <- utils::read.csv(result_path(root, "tables", sprintf("tied-%s-cap-%.0f.csv", label, cap)))
      rows$variant <- label; measured[[length(measured) + 1L]] <- rows
    }
  }
  measured <- do.call(rbind, measured)
  controls <- measured[measured$cap_bytes == 0, , drop = FALSE]
  defaults <- measured[measured$cap_bytes == MEASURED_CAP, , drop = FALSE]
  defaults <- do.call(rbind, lapply(seq_len(nrow(defaults)), function(i)
    as.data.frame(classify_zero_radius(as.list(defaults[i, , drop = FALSE]), controls), stringsAsFactors = FALSE)))
  pairs <- compare_tied_cases(defaults)
  if (anyNA(defaults$unretained_zero_radius_vertices) || !all(measured$identical))
    stop("tied exactness or zero-radius classification failed: ", root, call. = FALSE)
  utils::write.csv(pairs, result_path(root, "tables", "tied-comparison.csv"), row.names = FALSE)
  control_checks$dir <- NULL; stack_control_checks$dir <- NULL
  summary$priority_on_stack <- list(
    cap_bytes = MEASURED_CAP, cases = nrow(pairs), identical = sum(pairs$stack_identical & pairs$priority_identical),
    shared_control_checks = control_checks,
    shared_stack_checks = stack_summary$checks,
    shared_stack_control_checks = stack_control_checks,
    shared_timing = shared_timing, control_cases = nrow(controls), control_identical = sum(controls$identical),
    scope = list(timing_repetitions = 3, timed_entry = "shared/harness/common.R:native_se",
      cases_source = "shared/harness/tied.R", measurement_source = "shared/harness/tied.R",
      production_flags = "", measurement_flags = paste(flags_at(MEASURED_CAP), "-DLOESS_TESTING")),
    metrics = list(stack_cases_with_unretained_zero_radius = sum(pairs$stack_unretained_zero_radius_vertices > 0),
      priority_cases_with_unretained_zero_radius = sum(pairs$priority_unretained_zero_radius_vertices > 0),
      priority_cases_slower_than_nov6 = sum(pairs$priority_ratio > 1),
      native_bytes_unchanged = all(pairs$stack_baseline_native_bytes == pairs$priority_baseline_native_bytes),
      slowest_stack = as.list(pairs[which.max(pairs$stack_ratio), , drop = FALSE]),
      slowest_priority = as.list(pairs[which.max(pairs$priority_ratio), , drop = FALSE])),
    pairs = pairs, defaults = defaults, measurements = measured)
  write_json(summary, result_path(root, "json", "summary.json"))
  message(sprintf("tied comparison: %d/%d identical; stack zero-loss cases %d; priority zero-loss cases %d",
    summary$priority_on_stack$identical, nrow(pairs),
    summary$priority_on_stack$metrics$stack_cases_with_unretained_zero_radius,
    summary$priority_on_stack$metrics$priority_cases_with_unretained_zero_radius))
  summary
}

# Match ordinary timing cases and retain both contemporaneous Nov 6 references.
compare_shared_timing <- function(summary, stack_summary) {
  before <- stack_summary$timing[match(summary$timing$case, stack_summary$timing$case), , drop = FALSE]
  if (anyNA(before$case)) stop("missing plain stack timing for ",
    paste(summary$timing$case[is.na(before$case)], collapse = ", "), call. = FALSE)
  data.frame(case = summary$timing$case, stack_s = before$variant_s, priority_s = summary$timing$variant_s,
    stack_nov6_s = before$nov6_s, priority_nov6_s = summary$timing$nov6_s,
    stack_ratio = before$ratio, priority_ratio = summary$timing$ratio,
    priority_to_stack_ratio = summary$timing$ratio / before$ratio,
    priority_to_stack_seconds = summary$timing$variant_s / before$variant_s)
}

# Preserve the original before/after columns and classify lost zero-radius vertices with controls.
compare_tied_cases <- function(defaults) {
  stack_rows <- defaults[defaults$variant == "stack", , drop = FALSE]
  do.call(rbind, lapply(seq_len(nrow(stack_rows)), function(i) {
    before <- stack_rows[i, , drop = FALSE]
    after <- defaults[defaults$variant == "priority" & defaults$id == before$id, , drop = FALSE]
    if (nrow(after) != 1L) stop("missing priority comparison for ", before$id, call. = FALSE)
    row <- as.list(before[c("id", "family", "d", "n", "m", "zero_radius_vertices", "needed_vertices", "public_error", "nan_variances")])
    sources <- list(stack = before, priority = after)
    for (label in names(sources)) for (key in c("identical", "public_identical", "native_identical", "matrix_identical",
      "unretained_zero_radius_vertices", "replay_vertex_fits", "nov6_s", "baseline_s", "ratio",
      "baseline_native_bytes", "nov6_native_bytes", "nov6_L_bytes", "exceptional_zero_radius_confirmed"))
      row[[paste(label, key, sep = "_")]] <- sources[[label]][[key]]
    row$priority_to_stack_seconds <- after$baseline_s / before$baseline_s
    as.data.frame(row, stringsAsFactors = FALSE)
  }))
}
