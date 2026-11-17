# Interleave public ordinary predictions and native tied variances for all requested package variants.

measure_timing <- function(root) {
  methods <- load_packages(root); names(methods)[names(methods) == "package"] <- "source"
  rounds <- list(); step <- progress(length(timing_cases) + nrow(measurement_cases()))
  ordinary <- lapply(seq_along(timing_cases), function(i) {
    id <- names(timing_cases)[i]; cs <- timing_cases[[i]]; step(i, id)
    data <- timing_data(cs); calls <- prediction_calls(data$fit, data$nd, methods)
    values <- lapply(calls, function(call) capture(call()))
    exact <- same_outputs(values, id, root)
    if (inherits(values$r$value, "error-message")) stop("ordinary public prediction failed: ", id)
    nrounds <- if (cs[2L] > 5000L) 5L else 9L
    seconds <- interleaved_seconds(calls, nrounds)
    rounds[[length(rounds) + 1L]] <<- timing_rounds(id, "ordinary-public", seconds)
    row <- timing_row(id, seconds, exact, data.frame(d = cs[1L], n = cs[2L], m = cs[3L], rounds = nrounds))
    save_timing(root, "ordinary-timing.csv", row, rounds, i == 1L)
  })
  ordinary <- do.call(rbind, ordinary)
  cases <- measurement_cases()
  tied <- lapply(seq_len(nrow(cases)), function(i) {
    cs <- cases[i, ]; step(length(timing_cases) + i, cs$id); input <- case_input(cs)
    data <- data.frame(input$X, y = input$y)
    fitted <- capture(stats::loess(reformulate(colnames(input$X), response = "y"), data,
      span = cs$span, control = stats::loess.control(cell = cs$cell)))
    if (inherits(fitted$value, "error-message")) stop("tied fit failed for ", cs$id, ": ", fitted$value)
    public <- lapply(prediction_calls(fitted$value, input$nd, methods), function(call) capture(call()))
    public_exact <- same_outputs(public, cs$id, root)
    public_error <- inherits(public$r$value, "error-message")
    saveRDS(list(case = cs, fit_warnings = fitted$warnings, predictions = public),
      result_path(root, "diagnostics", paste0(cs$id, "-public.rds")))
    calls <- variance_calls(input, cs, methods)
    native <- lapply(calls, function(call) capture(call()))
    native_exact <- same_outputs(native, cs$id, root)
    if (inherits(native$r$value, "error-message")) stop("tied native variance failed: ", cs$id)
    seconds <- interleaved_seconds(calls, 3L)
    rounds[[length(rounds) + 1L]] <<- timing_rounds(cs$id, "tied-native", seconds)
    row <- timing_row(cs$id, seconds, public_exact && native_exact,
      data.frame(family = cs$family, d = cs$d, n = cs$n, m = nrow(input$nd), span = cs$span,
        cell = cs$cell, rounds = 3L, public_identical = public_exact, native_identical = native_exact,
        public_error, public_warning_count = length(public$r$warnings),
        native_warning_count = length(native$r$warnings), nan_variances = sum(is.nan(native$r$value))))
    save_timing(root, "tied-timing.csv", row, rounds, i == 1L)
  })
  tied <- do.call(rbind, tied)
  message(sprintf("all variants: %d/%d ordinary, %d/%d tied identical", sum(ordinary$identical), nrow(ordinary),
    sum(tied$identical), nrow(tied)))
}

# Build closures once per method so every call keeps its own wrapper and native-symbol bindings.

prediction_calls <- function(fit, nd, methods, include_r = TRUE) {
  calls <- lapply(methods, function(method) { force(method); function() method$predict_se(fit, nd) })
  if (include_r) c(list(r = function() stats::predict(fit, nd, se = TRUE)), calls) else calls
}

variance_calls <- function(input, cs, methods, include_r = TRUE) {
  calls <- lapply(methods, function(method) {
    force(method); function() native_se(method, input$X, input$y, input$nd, cs, TRUE)
  })
  if (include_r) c(list(r = function() r_native_se(input$X, input$y, input$nd, cs)), calls) else calls
}

# Never relax warning order, error comparison or NaN bit comparison for any variant.

same_outputs <- function(values, id, root, reference = "r") {
  ok <- vapply(values, function(value) same(values[[reference]], value), FALSE)
  if (!all(ok)) fail(id, result_path(root, "diagnostics", "comparison.csv"), values)
  TRUE
}

# Persist each complete input and its raw repetitions before the next expensive reference call.

save_timing <- function(root, table, row, rounds, first) {
  utils::write.table(row, result_path(root, "tables", table), sep = ",", row.names = FALSE,
    col.names = first, append = !first, qmethod = "double")
  utils::write.csv(do.call(rbind, rounds), result_path(root, "tables", "timing-rounds.csv"), row.names = FALSE)
  message(sprintf("%s: R %.6g s, package %.6g s, deletions_only %.6g s, reduced %.6g s",
    row$id, row$r_s, row$source_s, row$deletions_only_s, row$reduced_s))
  row
}

# Median user CPU seconds and ratios use the same source and R references for every variant.

timing_row <- function(id, seconds, exact, extra) {
  row <- data.frame(id, extra, identical = exact)
  for (name in names(seconds)) row[[paste0(name, "_s")]] <- seconds[[name]]
  for (name in PACKAGE_VARIANTS) {
    row[[paste0(name, "_to_source")]] <- seconds[[name]] / seconds[["source"]]
    row[[paste0(name, "_to_r")]] <- seconds[[name]] / seconds[["r"]]
  }
  row$load1 <- load1()
  row
}

# Per-round seconds already divide by the batch size used by the shared timing helper.

timing_rounds <- function(id, entry, seconds) {
  values <- attr(seconds, "rounds")
  data.frame(id, entry, round = rep(seq_len(nrow(values)), ncol(values)),
    implementation = rep(colnames(values), each = nrow(values)), user_s = as.vector(values))
}
