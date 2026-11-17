# Build one source variant (baseline plus one patch) and measure it the same way every time.
# source() after common.R; it defines functions only. Every function takes the experiment folder.
# An experiment with one variant keeps `variant.patch` and leaves `name` NULL. An experiment with several
# keeps `patches/<name>.patch` and passes `name`; its files then go to `.intermediates/<name>/` and to
# `.results/<kind>/<name>-<file>`.

MEASURED_CAP <- 67108864

# Build flags of every measurement: 32 column blocks and a retention cap in bytes.
flags_at <- function(cap) sprintf("-DLOESS_COEFFICIENT_BLOCK=32 -DLOESS_RETENTION_BYTES=%.0f", cap)

shared_dir <- function(exp_dir) file.path(dirname(dirname(exp_dir)), "shared")

# Private build folder of one variant.
variant_work <- function(exp_dir, name = NULL) {
  if (is.null(name)) file.path(exp_dir, ".intermediates") else file.path(exp_dir, ".intermediates", name)
}

# Path of one result file; kind is the purpose folder under .results (tables, json, logs, profile, ...).
result_path <- function(exp_dir, kind, file, name = NULL) {
  dir <- file.path(exp_dir, ".results", kind)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  file.path(dir, if (is.null(name)) file else paste0(name, "-", file))
}

# Run a command in cwd with its output in log; stop with the command line and the log tail when it fails.
sh <- function(cmd, args, cwd, log, env = character()) {
  shown <- paste(c(cmd, args), collapse = " ")
  message(sprintf("run: %s (cwd %s)", shown, cwd))
  assign <- if (length(env)) paste0(names(env), "=", shQuote(env), collapse = " ") else ""
  line <- paste("cd", shQuote(cwd), "&&", assign, "exec", paste(shQuote(c(cmd, args)), collapse = " "), ">", shQuote(log), "2>&1")
  status <- system(line)
  if (status != 0) {
    stop(sprintf("%s failed in %s with status %d; log %s ends:\n%s", shown, cwd, status, log,
      paste(utils::tail(readLines(log, warn = FALSE), 20), collapse = "\n")), call. = FALSE)
  }
  invisible(log)
}

# Run an R script as its own process. label gives the log and, when profile is TRUE, the worker's Rprof file.
worker <- function(exp_dir, script, args, label, profile = TRUE, name = NULL) {
  sh(file.path(R.home("bin"), "Rscript"),
    c(script, args, if (profile) result_path(exp_dir, "profile", paste0(label, ".Rprof"), name) else ""),
    cwd = variant_work(exp_dir, name), log = result_path(exp_dir, "logs", paste0(label, ".log"), name))
}

# Compile every .c and .f in dir into one shared library named so.
build <- function(dir, so, flags, log) {
  unlink(list.files(dir, "\\.(o|so)$", full.names = TRUE))
  sources <- sort(list.files(dir, "\\.(c|f)$"), method = "radix")
  sh(file.path(R.home("bin"), "R"), c("CMD", "SHLIB", "-o", so, sources), cwd = dir, log = log, env = c(PKG_CPPFLAGS = flags))
}

copy_dir <- function(from, to) {
  unlink(to, recursive = TRUE); dir.create(to, recursive = TRUE)
  ok <- file.copy(list.files(from, full.names = TRUE, all.files = TRUE, no.. = TRUE), to, recursive = TRUE)
  if (!all(ok)) stop("could not copy ", from, " to ", to, call. = FALSE)
}

# Copy a source tree and apply its one experiment patch; the caller owns the destination.

prepare_variant <- function(exp_dir, dir, base = "baseline", patch = file.path(exp_dir, "variant.patch"), log) {
  copy_dir(file.path(shared_dir(exp_dir), base), dir)
  if (file.exists(patch)) sh("patch", c("-p1", "-E", "--no-backup-if-mismatch", "-i", patch), cwd = dir, log = log)
  if (base == "reference-nov6") {
    adapter <- file.path(dir, "register.c")
    writeLines(sub("R_init_loesssent", "R_init_loessfactorpredict", readLines(adapter), fixed = TRUE), adapter)
  }
  invisible(dir)
}

# Lines added and removed against R, including the separate register.c build adapter.

line_count <- function(dir, ref) {
  files <- stats::setNames(list(), character())
  sources <- sort(union(list.files(dir, "\\.(c|f|h|R)$"), list.files(ref, "\\.(c|f|h|R)$")), method = "radix")
  for (f in sources) {
    before <- file.path(ref, f); after <- file.path(dir, f)
    if (file.exists(before) && file.exists(after)) {
      d <- suppressWarnings(system2("diff", shQuote(c(before, after)), stdout = TRUE, stderr = TRUE))
      status <- attr(d, "status")
      if (!is.null(status) && status != 1L) stop("diff failed for ", f, " with status ", status, ": ", paste(d, collapse = "\n"))
      n <- c(sum(startsWith(d, ">")), sum(startsWith(d, "<")))
    } else if (file.exists(after)) n <- c(length(readLines(after, warn = FALSE)), 0L)
    else n <- c(0L, length(readLines(before, warn = FALSE)))
    if (any(n > 0)) files[[f]] <- list(added = n[1], removed = n[2])
  }
  list(added = sum(vapply(files, `[[`, 0, "added")), removed = sum(vapply(files, `[[`, 0, "removed")), files = files)
}

# Rebuild the experiment's built variant with another retention cap and run the shared checks on it.
check_at_cap <- function(exp_dir, cap, profile = TRUE, name = NULL) {
  work <- variant_work(exp_dir, name)
  tag <- sprintf("cap-%.0f", cap)
  dir <- file.path(work, paste0("src-", tag)); table <- result_path(exp_dir, "tables", paste0("checks-", tag, ".csv"), name)
  copy_dir(file.path(work, "src"), dir)
  build(dir, "loessfactorpredict.so", flags_at(cap), result_path(exp_dir, "logs", paste0("build-", tag, ".log"), name))
  worker(exp_dir, file.path(shared_dir(exp_dir), "harness", "check.R"), c(dir, file.path(work, "reference-nov6"), table), paste0("check-", tag), profile, name)
  rows <- utils::read.csv(table)
  message(sprintf("cap %.0f: %d/%d identical", cap, sum(rows$ok), nrow(rows)))
  if (!all(rows$ok)) stop(sprintf("cap %.0f in %s: %d/%d identical, see %s", cap, exp_dir, sum(rows$ok), nrow(rows), table), call. = FALSE)
  list(cap_bytes = cap, cases = nrow(rows), identical = sum(rows$ok), dir = dir)
}

# Measure one variant and write tables/checks.csv, tables/timing.csv and json/summary.json.
# flags: preprocessor flags for the variant build; pass "" to test the source defaults.
# patch: defaults to variant.patch, or patches/<name>.patch when name is given; a missing default means no patch.
run_variant <- function(exp_dir, flags = flags_at(MEASURED_CAP), profile = TRUE, name = NULL,
    patch = if (is.null(name)) file.path(exp_dir, "variant.patch") else file.path(exp_dir, "patches", paste0(name, ".patch"))) {
  if (!is.null(name) && !file.exists(patch)) stop("no patch for variant ", name, ": ", patch, call. = FALSE)
  work <- variant_work(exp_dir, name); out <- function(kind, file) result_path(exp_dir, kind, file, name)
  shared <- shared_dir(exp_dir); src <- file.path(work, "src"); ref <- file.path(work, "reference-nov6")
  prepare_variant(exp_dir, src, patch = patch, log = out("logs", "patch.log"))
  copy_dir(file.path(shared, "reference-nov6"), ref)
  build(ref, "loesssent.so", "", out("logs", "build-reference.log"))
  build(src, "loessfactorpredict.so", flags, out("logs", "build-variant.log"))
  checks <- out("tables", "checks.csv"); timing <- out("tables", "timing.csv")
  worker(exp_dir, file.path(shared, "harness", "check.R"), c(src, ref, checks), "check", profile, name)
  worker(exp_dir, file.path(shared, "harness", "time.R"), c(src, ref, timing), "time", profile, name)
  c <- utils::read.csv(checks); t <- utils::read.csv(timing)
  suites <- lapply(split(c$ok, c$suite), function(ok) list(cases = length(ok), identical = sum(ok)))
  summary <- list(flags = flags, patch = file.exists(patch), lines = line_count(src, file.path(shared, "reference-r")),
    checks = list(cases = nrow(c), identical = sum(c$ok), suites = suites),
    timing = t[c("case", "nov6_s", "variant_s", "ratio", "native_bytes", "nov6_native_bytes", "nov6_L_bytes",
      "identical", "load1")])
  write_json(summary, out("json", "summary.json"))
  message(sprintf("checks %d/%d identical, lines +%d -%d", sum(c$ok), nrow(c), summary$lines$added, summary$lines$removed))
  if (!all(c$ok) || !all(t$identical)) stop(sprintf("variant in %s is not bit for bit identical: see %s and %s", exp_dir, checks, timing), call. = FALSE)
  summary
}
