# Compare flagged calls with the unchanged prototype and inspect deeper tree geometry.
run_flagged_cases <- function(root, profile = TRUE, name = NULL) {
  work <- variant_work(root, name)
  out <- function(kind, file) result_path(root, kind, file, name)
  src <- file.path(work, "src"); baseline <- file.path(work, "flagged-baseline")
  geometry <- file.path(work, "flagged-geometry")
  copy_dir(file.path(shared_dir(root), "baseline"), baseline)
  build(baseline, "loessfactorpredict.so", flags_at(MEASURED_CAP), out("logs", "build-flagged-baseline.log"))
  dir.create(geometry, recursive = TRUE, showWarnings = FALSE)
  geometry_source <- file.path(root, "src", "modules", "geometry-check.c")
  write_json(list(list(directory = geometry, file = geometry_source,
    arguments = c("clang", paste0("-I", R.home("include")), "-c", geometry_source))),
    file.path(geometry, "compile_commands.json"))
  if (!file.copy(geometry_source, geometry, overwrite = TRUE)) stop("could not copy ", geometry_source, " to ", geometry)
  objects <- sort(list.files(src, "\\.o$", full.names = TRUE), method = "radix")
  objects <- objects[basename(objects) != "register.o"]
  sh(file.path(R.home("bin"), "R"), c("CMD", "SHLIB", "-o", "geometrycheck.so", "geometry-check.c", objects),
    cwd = geometry, log = out("logs", "build-geometry.log"))
  checks_path <- out("tables", "flagged-checks.csv")
  geometry_path <- out("tables", "geometry-search.csv")
  timing_path <- out("tables", "flagged-timing.csv")
  worker(root, file.path(root, "src", "modules", "flagged-cases.R"),
    c(baseline, src, geometry, checks_path, geometry_path, timing_path),
    "flagged-cases", profile, name)
  checks <- utils::read.csv(checks_path); searches <- utils::read.csv(geometry_path)
  timing <- utils::read.csv(timing_path)
  data.frame(suite = c("flagged-cases", "flagged-timing", "geometry-search"),
    identical = c(sum(checks$matrix_identical & checks$warnings_identical & checks$returned_matrix),
      sum(timing$matrix_identical & timing$warnings_identical), NA_integer_),
    cases = c(nrow(checks), nrow(timing), nrow(searches)))
}
