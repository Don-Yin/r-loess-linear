# Probe copies measure requested bytes without adding instrumentation to the timed libraries.

measure_memory <- function(root) {
  methods <- load_packages(root)
  probes <- stats::setNames(lapply(names(methods), function(name) {
    dir <- native_build(root, package_dir(root, name), paste0("probe-", name), "-DLOESS_TESTING")
    source_wrapper(package_dir(root, name), dir, "loessfactorpredict.so")
  }), names(methods))
  step <- progress(length(timing_cases) + nrow(measurement_cases()))
  ordinary <- lapply(seq_along(timing_cases), function(i) {
    cs <- timing_cases[[i]]; id <- names(timing_cases)[i]; step(i, paste("ordinary memory", id))
    data <- timing_data(cs)
    memory_row(root, id, "ordinary-public", prediction_calls(data$fit, data$nd, methods, FALSE),
      prediction_calls(data$fit, data$nd, probes, FALSE), probes, cs[1L], cs[2L], cs[3L], cs[5L])
  })
  cases <- measurement_cases()
  tied <- lapply(seq_len(nrow(cases)), function(i) {
    cs <- cases[i, ]; step(length(timing_cases) + i, paste("tied memory", cs$id)); input <- case_input(cs)
    memory_row(root, cs$id, "tied-native", variance_calls(input, cs, methods, FALSE),
      variance_calls(input, cs, probes, FALSE), probes, cs$d, cs$n, nrow(input$nd), cs$span)
  })
  rows <- do.call(rbind, c(ordinary, tied))
  utils::write.csv(rows, result_path(root, "tables", "requested-bytes.csv"), row.names = FALSE)
  message(sprintf("memory: %d/%d inputs match across all production and probe libraries", sum(rows$identical), nrow(rows)))
}

# R requests come from its source; package requests come from the corresponding native probes.

memory_row <- function(root, id, entry, calls, probe_calls, probes, d, n, m, span) {
  values <- lapply(c(calls, stats::setNames(probe_calls, paste0("probe-", names(probe_calls)))),
    function(call) capture(call()))
  exact <- same_outputs(values, id, root, "package")
  if (any(vapply(values, function(value) inherits(value$value, "error-message"), FALSE)))
    stop("memory measurement failed for ", id)
  row <- data.frame(id, entry, d, n, m, identical = exact)
  for (name in names(probes)) {
    p <- probe_values(probes[[name]])
    row[[paste0(name, "_native_bytes")]] <- p$native_bytes
    row[[paste0(name, "_vertices")]] <- p$vertices
    row[[paste0(name, "_retained_bytes")]] <- p$retained_bytes
  }
  r <- reference_bytes(d, n, m, span, 2L, 0)
  row$r_native_bytes <- r[["native"]]; row$r_L_bytes <- r[["L"]]; row$r_native_and_L_bytes <- sum(r)
  row
}
