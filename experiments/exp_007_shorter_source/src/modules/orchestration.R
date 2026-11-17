# Build both requested reductions and measure them with one shared package and R comparison.

measure <- function(root, profile = TRUE) {
  Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
  project <- dirname(dirname(root)); reference <- file.path(variant_work(root), "reference")
  step <- progress(8L)
  step(1L, "build the package and shared reference")
  copy_package(project, package_dir(root, "package"))
  install_package(root, package_dir(root, "package"), "source")
  copy_dir(file.path(shared_dir(root), "reference-nov6"), reference)
  build(reference, "loesssent.so", "", result_path(root, "logs", "build-reference.log"))

  variants <- stats::setNames(lapply(seq_along(PACKAGE_VARIANTS), function(i) {
    name <- PACKAGE_VARIANTS[i]; step(i + 1L, paste("build and check", name, "at both caps"))
    package <- prepare_package(root, name)
    caps <- stats::setNames(lapply(c("default", "cap-0"), function(cap) {
      label <- paste(name, cap, sep = "-")
      library <- install_package(root, package, label, if (cap == "default") "" else flags_at(0))
      list(checks = package_checks(root, package, reference, library, label, profile),
        package_tests = package_tests(root, library, label, profile))
    }), c("default", "cap_zero"))
    list(source_lines = source_lines(package_dir(root, "package"), package), caps = caps,
      unchanged_native = unchanged_checks(root, package, reference, name, profile))
  }), PACKAGE_VARIANTS)

  step(4L, "count both reductions against the package and original R")
  physical <- do.call(rbind, lapply(names(variants), function(name)
    data.frame(variant = name, variants[[name]]$source_lines$physical)))
  utils::write.csv(physical, result_path(root, "tables", "source-lines.csv"), row.names = FALSE)
  paths <- stats::setNames(lapply(c("package", PACKAGE_VARIANTS), function(name) package_dir(root, name)),
    c("package", PACKAGE_VARIANTS))
  lines_against_r <- count_against_r(root, paths)

  step(5L, "build each requested addition to deletions_only")
  for (name in ADDITIONS) {
    package <- prepare_package(root, name)
    install_package(root, package, paste(name, "default", sep = "-"))
  }

  step(6L, "requested bytes and strict checks in separate probe builds")
  worker(root, file.path(root, "src/modules/package-worker.R"), c("memory", root, "", "all"), "memory", profile)

  step(7L, "isolate addition costs on the three one-predictor inputs")
  worker(root, file.path(root, "src/modules/package-worker.R"), c("additions", root, "", "all"), "additions", profile)

  step(8L, "ordinary and tied timing against the package and R")
  worker(root, file.path(root, "src/modules/package-worker.R"), c("timing", root, "", "all"), "timing", profile)
  ordinary <- utils::read.csv(result_path(root, "tables", "ordinary-timing.csv"))
  tied <- utils::read.csv(result_path(root, "tables", "tied-timing.csv"))
  memory <- utils::read.csv(result_path(root, "tables", "requested-bytes.csv"))
  additions <- utils::read.csv(result_path(root, "tables", "addition-timing.csv"))
  for (name in names(variants)) {
    variants[[name]]$timing <- list(ordinary = timing_summary(ordinary, name), tied = timing_summary(tied, name))
    variants[[name]]$memory <- list(cases = nrow(memory), identical = sum(memory$identical),
      native_bytes_equal_package = all(memory[[paste0(name, "_native_bytes")]] == memory$package_native_bytes))
  }
  profiles <- list.files(file.path(root, ".results/profile"), "\\.Rprof$", full.names = TRUE)
  summary <- list(variants = variants, lines_against_r = lines_against_r,
    additions = lapply(split(additions, additions$implementation), function(rows)
      list(cases = nrow(rows), identical = sum(rows$identical), to_package = range(rows$to_package),
        to_deletions_only = range(rows$to_deletions_only))),
    tied_public_predictions = sum(!tied$public_error), tied_public_errors = sum(tied$public_error),
    scope = list(default_cap_bytes = MEASURED_CAP, ordinary_rounds = "5 for N > 5000, otherwise 9",
      tied_rounds = 3L, addition_rounds = 9L, addition_batch = 20L,
      ordinary_entry = "predict_se", tied_entry = "shared/harness/common.R:native_se",
      cases_source = c("shared/harness/speed.R", "shared/harness/tied.R"),
      package_wrapper_checked = TRUE, removed_local_fit_checked = FALSE,
      timing_loading = "each source wrapper bound to its own installed native library",
      package_checks_loading = "each installed package namespace in a separate process"),
    platform = list(R = R.version.string, system = unname(Sys.info()[c("sysname", "machine")]),
      BLAS = unname(extSoftVersion()["BLAS"]), OPENBLAS_NUM_THREADS = 1L, OMP_NUM_THREADS = 1L),
    profiles = data.frame(file = basename(profiles), bytes = unname(file.info(profiles)$size)))
  write_json(summary, result_path(root, "json", "summary.json"))
  for (name in names(variants)) message(sprintf("%s: +%d -%d, %d source lines saved", name,
    variants[[name]]$source_lines$added, variants[[name]]$source_lines$removed, variants[[name]]$source_lines$saved))
  summary
}

# The installed-library mode fits with stats and calls the package's own R wrapper.

package_checks <- function(root, package, reference, library, label, profile) {
  table <- result_path(root, "tables", paste0("checks-", label, ".csv"))
  sh(file.path(R.home("bin"), "Rscript"),
    c(file.path(shared_dir(root), "harness/check.R"), package, reference, table,
      if (profile) result_path(root, "profile", paste0("checks-", label, ".Rprof")) else "", library),
    cwd = variant_work(root), log = result_path(root, "logs", paste0("checks-", label, ".log")))
  checked_rows(table)
}

# Read every CSV result rather than trusting the original harness's process exit.

checked_rows <- function(table) {
  rows <- utils::read.csv(table)
  if (nrow(rows) != 275L || !all(rows$ok))
    stop("shared checks in ", table, ": ", sum(rows$ok), "/", nrow(rows), " identical; expected 275/275")
  list(cases = nrow(rows), identical = sum(rows$ok),
    suites = lapply(split(rows$ok, rows$suite), function(ok) list(cases = length(ok), identical = sum(ok))))
}

# Run the unchanged package tests in an independent process for each installed library.

package_tests <- function(root, library, label, profile) {
  worker(root, file.path(root, "src/modules/package-worker.R"),
    c("tests", root, library, label), paste0("tests-", label), profile)
  jsonlite::read_json(result_path(root, "json", paste0("tests-", label, ".json")), simplifyVector = TRUE)
}

# Only the loader name changes in this control; the missing fitting entry still inherits stats.

unchanged_checks <- function(root, package, reference, name, profile) {
  label <- paste0("checks-unchanged-native-", name)
  dir <- native_build(root, package, paste0("native-control-", name))
  file.copy(file.path(shared_dir(root), "baseline/loess.R"), dir)
  table <- result_path(root, "tables", paste0(label, ".csv"))
  worker(root, file.path(shared_dir(root), "harness/check.R"), c(dir, reference, table), label, profile)
  checked_rows(table)
}

# Retain timing ranges and counts separately for the two requested variants.

timing_summary <- function(rows, name) {
  seconds <- rows[[paste0(name, "_s")]]
  list(cases = nrow(rows), identical = sum(rows$identical),
    to_package = range(rows[[paste0(name, "_to_source")]]), to_R = range(rows[[paste0(name, "_to_r")]]),
    faster_than_package = sum(seconds < rows$source_s), faster_than_R = sum(seconds < rows$r_s))
}
