# Compare original and priority retention, including a cap too small for every exceptional vertex.
verify_retention <- function(root, profile = TRUE, name = NULL) {
  work <- variant_work(root, name)
  out <- function(kind, file) result_path(root, kind, file, name)
  shared <- shared_dir(root); rows <- list(); cap_checks <- list()
  caps <- c(MEASURED_CAP, 65536, 0)
  for (i in seq_along(caps)) {
    cap <- caps[i]
    message(sprintf("[%d/%d] priority retention cap %.0f bytes", i, length(caps), cap))
    baseline <- file.path(work, sprintf("baseline-cap-%.0f", cap))
    copy_dir(file.path(shared, "baseline"), baseline)
    build(baseline, "loessfactorpredict.so", flags_at(cap), out("logs", sprintf("build-baseline-%.0f.log", cap)))
    variant <- file.path(work, "src")
    if (cap != MEASURED_CAP) {
      check <- check_at_cap(root, cap, profile = profile, name = name)
      variant <- check$dir; check$dir <- NULL
      cap_checks[[length(cap_checks) + 1L]] <- check
    }
    output <- out("tables", sprintf("retention-cap-%.0f.csv", cap))
    worker(root, file.path(root, "src", "modules", "retention.R"),
      c(variant, baseline, file.path(work, "reference-nov6"), output, as.character(cap)),
      sprintf("retention-cap-%.0f", cap), profile, name)
    rows[[i]] <- utils::read.csv(output)
  }
  measurements <- do.call(rbind, rows)
  summary <- list(cases = nrow(measurements), identical = sum(measurements$identical),
    cap_checks = cap_checks, measurements = measurements)
  write_json(summary, out("json", "retention.json"))
  if (!all(measurements$identical)) stop("priority retention changed a result in ", root, " variant ", name)
  rbind(data.frame(suite = vapply(cap_checks, function(x) paste0("cap-", x$cap_bytes), ""),
      identical = vapply(cap_checks, `[[`, 0, "identical"), cases = vapply(cap_checks, `[[`, 0, "cases")),
    data.frame(suite = "retention", identical = summary$identical, cases = summary$cases))
}
