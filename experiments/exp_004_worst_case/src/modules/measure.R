# Build the unchanged baseline once, then reuse its cap builds for every measurement.
measure <- function(root, profile = TRUE) {
  work <- variant_work(root)
  summary <- run_variant(root, profile = profile)
  caps <- c(MEASURED_CAP, 1048576, 65536, 0)
  summary$build_checks <- list(c(list(cap_bytes = caps[1L]), summary$checks))
  sources <- character(length(caps)); worst <- list(); step <- progress(7L)
  for (i in seq_along(caps)) {
    cap <- caps[i]; dir <- file.path(work, "src"); step(i, sprintf("retention cap %.0f bytes", cap))
    if (cap != caps[1L]) {
      check <- check_at_cap(root, cap, profile = profile)
      dir <- check$dir; check$dir <- NULL
      summary$build_checks[[length(summary$build_checks) + 1L]] <- check
    }
    sources[i] <- dir
    table <- result_path(root, "tables", sprintf("worst-cap-%.0f.csv", cap))
    worker(root, file.path(root, "src", "modules", "stress.R"),
      c(dir, file.path(work, "reference-nov6"), table, as.character(cap)), sprintf("worst-cap-%.0f", cap), profile)
    worst[[i]] <- utils::read.csv(table)
  }
  step(5L, "tree depth through 20 nodes")
  depth <- measure_depth(root, profile)
  worst <- do.call(rbind, worst)
  summary$worst_case <- list(cases = nrow(worst), identical = sum(worst$identical), measurements = worst)
  summary$depth <- list(cases = nrow(depth), identical = sum(depth$identical), measurements = depth)
  summary$tied_default_cap <- measure_tied(root, sources[1L], sources[length(caps)],
    summary$build_checks[[length(caps)]], step, profile)
  write_json(summary, result_path(root, "json", "summary.json"))
  if (!all(worst$identical) || !all(depth$identical)) stop("worst-case or depth exactness failed: ", root, call. = FALSE)
  message(sprintf("worst-case %d/%d; depth %d/%d identical", sum(worst$identical), nrow(worst), sum(depth$identical), nrow(depth)))
  summary
}

# Geometry uses the default build and reference, not another compilation.
measure_depth <- function(root, profile = TRUE) {
  work <- variant_work(root)
  geometry <- file.path(work, "geometry"); dir.create(geometry, recursive = TRUE, showWarnings = FALSE)

  # Distinct filenames leave both binaries' Fortran symbols available for geometry-only measurements.
  copies <- c(file.copy(file.path(work, "src", "loessfactorpredict.so"), file.path(geometry, "geometrybaseline.so"), overwrite = TRUE),
    file.copy(file.path(work, "reference-nov6", "loesssent.so"), file.path(geometry, "geometrynov6.so"), overwrite = TRUE))
  if (!all(copies)) stop("could not copy geometry libraries to ", geometry, call. = FALSE)
  table <- result_path(root, "tables", "depth.csv")
  worker(root, file.path(root, "src", "modules", "depth.R"), c(geometry, table), "depth", profile)
  utils::read.csv(table)
}

# Reuse the default and zero-cap builds for the deterministic tied-input cases; step continues the run's progress.
measure_tied <- function(root, default_dir, zero_dir, zero_check, step, profile = TRUE) {
  source(file.path(shared_dir(root), "harness", "tied.R"), local = TRUE)
  work <- variant_work(root); measurements <- list()
  caps <- c(MEASURED_CAP, 0)
  for (i in seq_along(caps)) {
    cap <- caps[i]; dir <- if (cap == 0) zero_dir else default_dir
    step(5L + i, sprintf("tied inputs at retention cap %.0f bytes", cap))
    worker(root, file.path(root, "src", "modules", "tied-worker.R"),
      c(root, dir, file.path(work, "reference-nov6"), as.character(cap)), sprintf("tied-cap-%.0f", cap), profile)
    measurements[[i]] <- utils::read.csv(result_path(root, "tables", sprintf("tied-cap-%.0f.csv", cap)))
  }
  measurements <- do.call(rbind, measurements)
  defaults <- measurements[measurements$cap_bytes == caps[1L], , drop = FALSE]
  zero_cap <- measurements[measurements$cap_bytes == 0, , drop = FALSE]
  findings <- do.call(rbind, lapply(seq_len(nrow(defaults)), function(i) {
    row <- classify_zero_radius(as.list(defaults[i, , drop = FALSE]), zero_cap)
    row$zero_cap_control <- row$id %in% zero_cap$id
    as.data.frame(row, stringsAsFactors = FALSE)
  }))
  reached <- findings[!is.na(findings$unretained_zero_radius_vertices) & findings$unretained_zero_radius_vertices > 0, , drop = FALSE]
  extremum <- function(key, rows = findings) if (nrow(rows)) as.list(rows[which.max(rows[[key]]), , drop = FALSE]) else NULL
  summary <- list(
    cap_bytes = caps[1L], cases = nrow(defaults), identical = sum(defaults$identical),
    control_cases = nrow(zero_cap), control_identical = sum(zero_cap$identical), shared_control_checks = list(zero_check),
    scope = list(predictors = 2:4, sample_sizes = c(4096, 8192), seed = 20261111,
      cells = c(.001, .005), spans = c(.0019, .0039, .2), timing_repetitions = 3,
      timed_entry = "shared/harness/common.R:native_se", source_changes = FALSE),
    metrics = list(cases_with_zero_radius = sum(findings$zero_radius_vertices > 0),
      cases_with_unretained_zero_radius = nrow(reached), largest_n = max(findings$n),
      most_vertices = extremum("vertices"), most_zero_radius_vertices = extremum("zero_radius_vertices"),
      most_unretained_zero_radius_vertices = extremum("unretained_zero_radius_vertices", reached),
      slowest_unretained_zero_radius = extremum("ratio", reached)),
    findings = findings, measurements = measurements)
  utils::write.csv(findings, result_path(root, "tables", "default-cap-findings.csv"), row.names = FALSE, na = "")
  if (anyNA(findings$unretained_zero_radius_vertices) || !all(measurements$identical))
    stop("tied-input exactness or zero-radius classification failed: ", root, call. = FALSE)
  message(sprintf("default cap: %d/%d identical; %d cases leave a zero-radius vertex unretained",
    sum(defaults$identical), nrow(defaults), nrow(reached)))
  summary
}
