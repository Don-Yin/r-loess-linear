# Saved standard sweeps; source after common.R, variant.R, memory.R and growth-builds.R.

growth_sizes <- function() as.integer(10^seq(2, log10(45000), length.out = 12))

growth_reference_lines <- function(root) {
  dir <- file.path(root, "shared/reference-r")
  files <- setdiff(sort(list.files(dir, "[.](c|f|h|R)$"), method = "radix"), "register.c")
  lapply(files, function(file) list(path = file.path("shared/reference-r", file),
    lines = length(readLines(file.path(dir, file), warn = FALSE))))
}

growth_call <- function(call) {
  value <- NULL; clock <- bench::system_time(value <- capture(call()))
  list(value = value, seconds = unname(as.numeric(clock[["real"]])))
}

growth_exact <- function(reference, value, label, n, out) {
  if (!same(reference, value) || inherits(value$value, "error-message"))
    fail(paste0(label, "-n", n), out, reference = reference, actual = value)
}

growth_reference <- function(root) {
  id <- "r-growth"; dir <- file.path(root, "experiments/shared/artifacts", id)
  if (!dir.exists(dir)) return(NULL)
  manifest <- jsonlite::read_json(file.path(dir, "manifest.json"))
  if (manifest$schema_version != 1L || manifest$artifact_id != id || manifest$runtime$threads != 1L ||
      !identical(vapply(manifest$files, `[[`, "", "path"), c("growth.csv", "predictions.rds")) ||
      any(vapply(manifest$files, `[[`, "", "storage") != "git")) stop("invalid shared R manifest: ", dir)
  rows <- utils::read.csv(file.path(dir, "growth.csv"), stringsAsFactors = FALSE)
  saved <- readRDS(file.path(dir, "predictions.rds"))
  if (!identical(rows$N, growth_sizes()) || !identical(saved$N, rows$N) ||
      length(saved$predictions) != nrow(rows) || !all(rows$identical_to_r) ||
      any(rows$repetitions < 1L | rows$repetitions %% 1 != 0) ||
      any(rows$memory_method != "source_formula")) stop("invalid shared R sweep: ", dir)
  list(rows = rows, predictions = saved$predictions)
}

growth_r_calls <- function(data, reference, n, out) {
  force(data); seconds <- numeric(5L)
  for (r in 1:5) {
    gc(); observed <- growth_call(function() predict(data$fit, data$nd, se = TRUE))
    if (is.null(reference)) reference <- observed$value
    growth_exact(reference, observed$value, "R", n, out)
    seconds[r] <- observed$seconds
  }
  list(value = reference, seconds = seconds)
}

growth_r_row <- function(n, seconds) {
  data.frame(build = "R", N = n, repetitions = length(seconds), median_seconds = median(seconds),
    min_seconds = min(seconds), max_seconds = max(seconds), sd_seconds = sd(seconds),
    requested_bytes = reference_bytes(1, n, 80, 0.5, 2, 0)[["native"]],
    identical_to_r = TRUE, memory_method = "source_formula")
}

growth_freeze <- function(root, rows, predictions, runtime) {
  dir <- file.path(root, "experiments/shared/artifacts/r-growth")
  if (dir.exists(dir)) stop("refusing to overwrite frozen artifact: ", dir)
  dir.create(dir, recursive = TRUE)
  saveRDS(list(N = rows$N, predictions = predictions), file.path(dir, "predictions.rds"))
  growth_write_reference(root, rows, runtime)
}

growth_write_reference <- function(root, rows, runtime) {
  id <- "r-growth"; dir <- file.path(root, "experiments/shared/artifacts", id)
  utils::write.csv(rows, file.path(dir, "growth.csv"), row.names = FALSE)
  sources <- growth_reference_lines(root)
  write_json(list(schema_version = 1L, artifact_id = id, producer_experiment = GROWTH_EXPERIMENTS[["prototype"]],
    files = list(list(path = "growth.csv", storage = "git"), list(path = "predictions.rds", storage = "git")),
    input = list(generator = "shared/harness/common.R:toby_data", seed = 20261105L, predictors = 1L,
      prediction_points = 80L, span = 0.5, cell = 0.2, grid = "as.integer(10^seq(2, log10(45000), length.out = 12))"),
    reference_source_lines = sum(vapply(sources, `[[`, 0L, "lines")), reference_sources = sources,
    runtime = runtime,
    timing = "five elapsed public predict(se = TRUE) calls per N in a fresh worker; median, min, max and sd; setup and gc outside the clock",
    requested_memory = "native workspace source formula; excludes the returned influence matrix"), file.path(dir, "manifest.json"))
  writeLines(c("# R growth reference", "", "- purpose: R timings and exact predictions",
    "- producer: exp_002_baseline_prototype; shared/harness/growth-worker.R",
    "- inputs: shared/harness/common.R:toby_data; shared/harness/memory.R; OMP_NUM_THREADS=1; BLAS threads=1",
    "- timing: five elapsed predict(se=TRUE) calls/N; median, min, max, sd; setup/gc untimed",
    "- consumers: standard R figures",
    "- regenerate: Rscript shared/harness/growth-worker.R --experiments=002,005 (existing artifact reused; never overwritten)"), file.path(dir, "README.md"))
}

# Each experiment owns one table, including all its selected builds.

growth_save <- function(entries, rows, rounds) {
  for (experiment in unique(vapply(entries, `[[`, "", "experiment"))) {
    keys <- names(entries)[vapply(entries, `[[`, "", "experiment") == experiment]
    owner <- entries[[keys[1]]]$exp_dir
    collect <- function(values) do.call(rbind, lapply(values[keys], function(x) do.call(rbind, x)))
    utils::write.csv(collect(rows), result_path(owner, "tables", "growth.csv"), row.names = FALSE)
    utils::write.csv(collect(rounds), result_path(owner, "tables", "growth-rounds.csv"), row.names = FALSE)
  }
}

run_growth <- function(root, labels, rounds = 9L) {
  if (!requireNamespace("bench", quietly = TRUE)) stop("bench is required by the saved timing workflow")
  started <- Sys.time(); specs <- growth_specs(root)
  owner <- file.path(root, "experiments", specs[[labels[1]]]$experiment)
  runtime <- growth_blas_runtime(root, owner)
  if (runtime$threads != 1L) stop("expected one thread; BLAS reports ", runtime$threads)
  reference <- growth_reference(root); reused <- !is.null(reference)
  if (!reused && !"prototype" %in% labels) stop("create the shared R artifact with experiment 002 first")
  entries <- growth_builds(root, labels)
  warm <- toby_data(100L)
  for (entry in entries) capture(entry$predict(warm))
  rows <- raw <- stats::setNames(lapply(entries, function(x) list()), names(entries))
  r_rows <- r_values <- list(); step <- progress(length(growth_sizes()))
  for (i in seq_along(growth_sizes())) {
    n <- growth_sizes()[i]; step(i, paste0("N = ", n)); data <- toby_data(n)
    if (reused) ref <- reference$predictions[[i]] else {
      observed <- growth_r_calls(data, NULL, n, result_path(owner, "tables", "growth.csv")); ref <- observed$value
      r_rows[[i]] <- growth_r_row(n, observed$seconds)
      r_values[[i]] <- ref
    }
    times <- matrix(NA_real_, rounds, length(entries), dimnames = list(NULL, names(entries)))
    bytes <- stats::setNames(numeric(length(entries)), names(entries))
    for (r in seq_len(rounds)) for (key in if (r %% 2L) names(entries) else rev(names(entries))) {
      entry <- entries[[key]]; gc(); observed <- growth_call(function() entry$predict(data))
      growth_exact(ref, observed$value, key, n, result_path(entry$exp_dir, "tables", "growth.csv"))
      times[r, key] <- observed$seconds
      if (entry$memory_method == "probe" && is.null(entry$probe)) bytes[key] <- probe_values(entry$plain)$native_bytes
    }
    for (key in names(entries)) {
      entry <- entries[[key]]
      if (!is.null(entry$probe)) {
        growth_exact(ref, capture(entry$predict_probe(data)), paste0(key, "-probe"), n,
          result_path(entry$exp_dir, "tables", "growth.csv"))
        bytes[key] <- probe_values(entry$probe)$native_bytes
      }
      if (entry$kind == "matrix") {
        nv <- unname(data$fit$kd$parameter["nv"])
        bytes[key] <- reference_bytes(1, n, 80, 0.5, 2, nv,
          coefficient_vertices = if (entry$variant == "actual_vertices") nv else max(200, n))[["native"]]
      }
      if (!is.finite(bytes[key]) || bytes[key] <= 0) stop("invalid requested bytes: ", key, " N=", n, " bytes=", bytes[key])
      s <- times[, key]
      rows[[key]][[i]] <- data.frame(build = entry$variant, N = n, repetitions = rounds, median_seconds = median(s),
        min_seconds = min(s), max_seconds = max(s), sd_seconds = sd(s), requested_bytes = bytes[key],
        identical_to_r = TRUE, memory_method = entry$memory_method)
      raw[[key]][[i]] <- data.frame(build = entry$variant, N = n, repetition = seq_len(rounds), seconds = s)
      message(sprintf("%s N=%d: %.6g s; %.0f requested bytes; identical", key, n, median(s), bytes[key]))
    }
    growth_save(entries, rows, raw)
  }
  if (!reused) growth_freeze(root, do.call(rbind, r_rows), r_values, runtime)
  record <- list(elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")), runtime = runtime,
    reference_reused = reused, reference_artifact = "r-growth",
    build_repetitions = rounds, timing = "median elapsed public predict(se = TRUE), strict captured-output identical()",
    builds = lapply(entries, function(x) x[c("experiment", "variant", "source_variant", "flags", "source_dir", "probe_dir", "memory_method")]))
  write_json(record, result_path(owner, "json", "growth-run.json"))
  message(sprintf("growth complete in %.3f seconds; BLAS reports %d threads", record$elapsed_seconds, runtime$threads))
}

# Correct the unreleased one-call timings once; saved predictions never pass through a writer.

growth_reference_timing <- function(root) {
  reference <- growth_reference(root)
  if (is.null(reference) || any(reference$rows$repetitions != 1L))
    stop("R timing correction requires the unreleased one-call artifact")
  owner <- file.path(root, "experiments", GROWTH_EXPERIMENTS[["prototype"]])
  runtime <- growth_blas_runtime(root, owner)
  if (runtime$threads != 1L) stop("expected one thread; BLAS reports ", runtime$threads)
  out <- result_path(owner, "tables", "r-growth-rounds.csv")
  rows <- raw <- list(); step <- progress(nrow(reference$rows))
  for (i in seq_len(nrow(reference$rows))) {
    n <- reference$rows$N[i]; step(i, paste0("R N = ", n, ", five calls"))
    observed <- growth_r_calls(toby_data(n), reference$predictions[[i]], n, out)
    rows[[i]] <- growth_r_row(n, observed$seconds)
    if (rows[[i]]$requested_bytes != reference$rows$requested_bytes[i]) stop("R requested bytes changed at N=", n)
    raw[[i]] <- data.frame(build = "R", N = n, repetition = 1:5, seconds = observed$seconds)
    utils::write.csv(do.call(rbind, raw), out, row.names = FALSE)
    utils::write.csv(do.call(rbind, rows), result_path(owner, "tables", "r-growth.csv"), row.names = FALSE)
    message(sprintf("R N=%d: median %.9g s; identical outputs and requested bytes", n, median(observed$seconds)))
  }
  message("all 60 R outputs identical to saved predictions; requested bytes equal at all 12 N; publishing timings")
  growth_write_reference(root, do.call(rbind, rows), runtime)
  write_json(list(runtime = runtime, repetitions = 5L, fresh_process = TRUE,
    comparison = "all 60 captured outputs identical() to saved predictions; requested bytes equal at every N",
    prediction_file_rewritten = FALSE), result_path(owner, "json", "r-growth-run.json"))
}

# Select the standard grid from Python's saved observations, retaining its other measurements.

growth_python <- function(root) {
  owner <- file.path(root, "experiments/exp_008_python_skmisc")
  raw <- utils::read.csv(result_path(owner, "tables", "measurements.csv"))
  raw <- raw[raw$n %in% growth_sizes(), , drop = FALSE]
  if (!identical(sort(unique(raw$n)), growth_sizes())) stop("Python measurements lack the standard N grid")
  checks <- utils::read.csv(result_path(owner, "tables", "checks.csv"))
  if (!all(checks$bitwise_equal)) stop("Python builds disagree in the saved checks table")
  groups <- split(raw, interaction(raw$build, raw$n, drop = TRUE))
  rows <- do.call(rbind, lapply(groups, function(x) {
    ok <- all(x$status == "ok")
    if (ok && (!all(x$trace_verified) || any(x$native_bytes != x$observed_native_bytes))) stop("unverified native allocation at N=", x$n[1])
    s <- x$prediction_seconds
    data.frame(build = x$build[1], N = x$n[1], repetitions = nrow(x), status = x$status[1],
      median_seconds = if (ok) median(s) else NA_real_, min_seconds = if (ok) min(s) else NA_real_,
      max_seconds = if (ok) max(s) else NA_real_, sd_seconds = if (ok) sd(s) else NA_real_,
      requested_bytes = if (ok) unique(x$observed_native_bytes) else NA_real_, identical_to_reference = ok,
      memory_method = "allocation_trace")
  }))
  utils::write.csv(rows[order(rows$build, rows$N), ], result_path(owner, "tables", "growth.csv"), row.names = FALSE)
  utils::write.csv(data.frame(build = raw$build, N = raw$n, repetition = raw$replicate + 1L,
    seconds = raw$prediction_seconds), result_path(owner, "tables", "growth-rounds.csv"), row.names = FALSE)
  source_root <- file.path(variant_work(owner), "sources")
  ref <- file.path(source_root, "unpatched/skmisc/loess/src")
  files <- list.files(ref, "[.](c|f|h|R)$")
  total <- sum(vapply(file.path(ref, files), function(path) length(readLines(path, warn = FALSE)), 0L))
  saved <- utils::read.csv(result_path(owner, "tables", "lines-against-skmisc.csv"))
  for (i in seq_len(nrow(saved))) {
    counts <- line_count(file.path(source_root, saved$variant[i], "skmisc/loess/src"), ref)
    if (counts$added != saved$added[i] || counts$removed != saved$removed[i]) stop("Python source count differs for ", saved$variant[i])
  }
  saved$reference_lines <- total
  utils::write.csv(saved, result_path(owner, "tables", "growth-source-lines.csv"), row.names = FALSE)
  message("Python saved observations converted; source total ", total)
}
