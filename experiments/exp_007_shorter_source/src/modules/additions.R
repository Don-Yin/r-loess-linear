# Each additional patch is a requested attribution comparison, never another production fallback.

measure_additions <- function(root) {
  methods <- load_packages(root, c("package", PACKAGE_VARIANTS, ADDITIONS))
  names(methods)[names(methods) == "package"] <- "source"
  cases <- timing_cases[vapply(timing_cases, function(cs) cs[1L] == 1L, FALSE)]
  step <- progress(length(cases)); rounds <- list(); rows <- list()
  for (i in seq_along(cases)) {
    id <- names(cases)[i]; cs <- cases[[i]]; step(i, paste("one-at-a-time addition", id))
    data <- timing_data(cs); calls <- prediction_calls(data$fit, data$nd, methods)
    values <- lapply(calls, function(call) capture(call()))
    exact <- same_outputs(values, id, root)
    if (inherits(values$r$value, "error-message")) stop("addition prediction failed: ", id)
    seconds <- interleaved_seconds(calls[names(calls) != "r"], 9L, batch = 20L)
    rounds[[i]] <- timing_rounds(id, "addition-public", seconds)
    rows[[i]] <- data.frame(id, d = cs[1L], n = cs[2L], m = cs[3L], implementation = names(seconds),
      rounds = 9L, batch = 20L, identical = exact, user_s = unname(seconds),
      to_package = unname(seconds / seconds[["source"]]),
      to_deletions_only = unname(seconds / seconds[["deletions_only"]]), load1 = load1())
    utils::write.csv(do.call(rbind, rows), result_path(root, "tables", "addition-timing.csv"), row.names = FALSE)
    utils::write.csv(do.call(rbind, rounds), result_path(root, "tables", "addition-rounds.csv"), row.names = FALSE)
    message(paste(c(id, sprintf("%s=%.6g", names(seconds), seconds)), collapse = " "))
  }
}
