# Build and measure the two steps that still return the full influence matrix.

run_matrix_variant <- function(exp_dir, compact, profile = TRUE) {
  shared <- shared_dir(exp_dir); work <- variant_work(exp_dir)
  out <- function(kind, file) result_path(exp_dir, kind, file)
  src <- file.path(work, "src"); ref <- file.path(work, "reference-r"); nov6 <- file.path(work, "reference-nov6")
  patch <- file.path(exp_dir, "variant.patch")
  if (file.exists(patch) != compact) stop("patch presence differs from compact=", compact, ": ", patch)
  prepare_variant(exp_dir, src, base = "reference-nov6", patch = patch, log = out("logs", "patch.log"))
  copy_dir(file.path(shared, "reference-r"), ref); copy_dir(file.path(shared, "reference-nov6"), nov6)
  build(src, "loessfactorpredict.so", "", out("logs", "build-variant.log"))
  build(ref, "loesssent.so", "", out("logs", "build-original.log"))
  build(nov6, "loesssent.so", "", out("logs", "build-cache-reference.log"))
  checks <- out("tables", "checks.csv"); timing <- out("tables", "timing.csv")
  worker(exp_dir, file.path(shared, "harness", "check.R"), c(src, nov6, checks), "check", profile)
  rows <- utils::read.csv(checks)
  if (!all(rows$ok)) stop("shared checks failed in ", exp_dir, ": ", sum(rows$ok), "/", nrow(rows), "; see ", checks)
  worker(exp_dir, file.path(shared, "harness", "matrix-time.R"),
    c(src, ref, timing, if (compact) "actual-vertices" else "cache"), "time", profile)
  measured <- utils::read.csv(timing)
  summary <- list(source = "shared/reference-nov6", patch = compact, flags = "", reference = "shared/reference-r",
    lines = line_count(src, file.path(shared, "reference-r")),
    checks = list(cases = nrow(rows), identical = sum(rows$ok),
      suites = lapply(split(rows$ok, rows$suite), function(ok) list(cases = length(ok), identical = sum(ok)))),
    memory = list(method = "source allocation formulas", includes = "native workspace, coefficients and inverse-neighbor cache",
      excludes = "R input copies, allocator overhead and temporary arrays; L is recorded separately"), timing = measured)
  write_json(summary, out("json", "summary.json"))
  if (!all(measured$identical)) stop("timing exactness failed in ", exp_dir, "; see ", timing)
  message(sprintf("checks %d/%d identical, lines against R +%d -%d", sum(rows$ok), nrow(rows),
    summary$lines$added, summary$lines$removed))
  invisible(summary)
}
