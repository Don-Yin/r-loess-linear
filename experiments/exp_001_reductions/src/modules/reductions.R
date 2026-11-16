# Run each independent reduction and collect the common and variant-specific evidence.
run_reductions <- function(root, profile = TRUE) {
  variants <- utils::read.csv(file.path(root, "src", "variants.csv"), colClasses = "character", na.strings = NULL)
  rows <- list(); step <- progress(nrow(variants))
  for (i in seq_len(nrow(variants))) {
    variant <- variants[i, ]; name <- variant$name; step(i, paste("reduction", name))
    flags <- if (name == "source_defaults") "" else flags_at(MEASURED_CAP)
    summary <- run_variant(root, flags = flags, profile = profile, name = name)
    extra <- data.frame(suite = character(), identical = integer(), cases = integer())
    if (nzchar(variant$module)) {
      source(file.path(root, "src", "modules", variant$module))
      extra <- get(variant$runner, mode = "function")(root, profile = profile, name = name)
    }
    write_json(extra, result_path(root, "json", "extra-checks.json", name))
    comparisons <- !is.na(extra$identical)
    extra_counts <- if (nrow(extra)) paste(paste0(extra$suite, "=", ifelse(comparisons,
      paste0(extra$identical, "/", extra$cases), extra$cases)), collapse = "; ") else "none"
    timing <- summary$timing
    bytes <- timing$native_bytes[timing$case == "d1-n45000-m80-cell0.2"]
    bytes_source <- "production"
    if (name == "probes_out_of_production") {
      testing <- utils::read.csv(result_path(root, "tables", "testing-timing.csv", name))
      bytes <- testing$native_bytes[testing$n == 45000]
      bytes_source <- "testing-build"
    }
    rows[[i]] <- cbind(data.frame(name, identical = summary$checks$identical, cases = summary$checks$cases,
        lines_added = summary$lines$added, lines_removed = summary$lines$removed),
      as.data.frame(stats::setNames(as.list(timing$ratio), paste0("ratio_", timing$case)), check.names = FALSE),
      data.frame(native_bytes_n45000 = bytes, native_bytes_source = bytes_source,
        extra_identical = sum(extra$identical[comparisons]), extra_cases = sum(extra$cases[comparisons]),
        extra_check_counts = extra_counts, verdict = variant$verdict, reason = variant$reason))
    utils::write.csv(do.call(rbind, rows), result_path(root, "tables", "reductions.csv"), row.names = FALSE)
  }
  invisible(do.call(rbind, rows))
}
