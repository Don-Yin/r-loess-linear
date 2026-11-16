# Verify the production boundary and measure the separately instrumented build.
verify_builds <- function(root, profile = TRUE, name = NULL) {
  work <- variant_work(root, name)
  out <- function(kind, file) result_path(root, kind, file, name)
  shared <- shared_dir(root); harness <- file.path(shared, "harness")
  production <- file.path(work, "src"); testing <- file.path(work, "testing")
  baseline <- file.path(work, "baseline-probes"); reference <- file.path(work, "reference-nov6")
  flags <- flags_at(MEASURED_CAP)
  copy_dir(production, testing); copy_dir(file.path(shared, "baseline"), baseline)
  build(testing, "loessfactorpredict.so", paste(flags, "-DLOESS_TESTING"), out("logs", "build-testing.log"))
  build(baseline, "loessfactorpredict.so", flags, out("logs", "build-baseline-probes.log"))
  checks_path <- out("tables", "testing-checks.csv")
  timing_path <- out("tables", "testing-timing.csv")
  api_path <- out("json", "test-api.json")
  worker(root, file.path(harness, "check.R"), c(testing, reference, checks_path), "testing-check", profile, name)
  worker(root, file.path(harness, "time.R"), c(testing, reference, timing_path), "testing-time", profile, name)
  worker(root, file.path(root, "src", "modules", "test-api.R"),
    c(production, testing, baseline, api_path), "test-api", profile, name)
  checks <- utils::read.csv(checks_path); timing <- utils::read.csv(timing_path)
  api <- jsonlite::read_json(api_path)
  test_names <- c("loess_factor_L", "loess_probe", "loess_block_probe", "loess_geometry_probe",
    "loess_retention_probe", "loess_exception_probe", "factor_observed", "factor_geometry_bytes",
    "retention_observed", "factor_exceptional")
  binaries <- list()
  for (kind in c("production", "testing")) {
    dir <- if (kind == "production") production else testing
    library <- file.path(dir, "loessfactorpredict.so")
    symbols_path <- out("logs", paste0(kind, "-symbols.log"))
    sh("nm", c("-a", library), cwd = work, log = symbols_path)
    symbols <- sub("^_", "", sub(".*[[:space:]]", "", trimws(readLines(symbols_path, warn = FALSE))))
    binaries[[kind]] <- list(bytes = unname(file.info(library)$size), test_symbols = test_names[test_names %in% symbols])
  }
  summary <- list(testing_flags = paste(flags, "-DLOESS_TESTING"),
    checks = list(cases = nrow(checks), identical = sum(checks$ok)),
    timing = timing[c("case", "ratio", "native_bytes", "identical")], binaries = binaries)
  path <- out("json", "testing-build.json")
  write_json(summary, path)
  if (!all(checks$ok) || !all(timing$identical) || length(binaries$production$test_symbols) ||
      length(binaries$testing$test_symbols) != length(test_names)) {
    stop("production/test boundary verification failed: ", path, call. = FALSE)
  }
  message(sprintf("production has no test symbols; testing checks %d/%d identical", sum(checks$ok), nrow(checks)))
  data.frame(suite = c("testing-build", "test-api"),
    identical = c(sum(checks$ok), api$identical), cases = c(nrow(checks), api$cases))
}
