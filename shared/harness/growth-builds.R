# Build recipes and runtime readings for saved growth sweeps; sources are private measurement copies.

GROWTH_EXPERIMENTS <- c(cache = "exp_000_nov6_cache", actual_vertices = "exp_001_actual_vertices",
  prototype = "exp_002_baseline_prototype", package = "exp_005_package_source")

growth_specs <- function(root) {
  recipe <- function(experiment, variant, flags = "", patch = "variant.patch", base = "baseline",
      probe = FALSE, kind = "flat", source_variant = variant) {
    list(experiment = experiment, variant = variant, flags = flags, patch = patch, base = base,
      needs_probe = probe, kind = kind, source_variant = source_variant)
  }
  specs <- list(
    cache = recipe(GROWTH_EXPERIMENTS[["cache"]], "cache", base = "reference-nov6", kind = "matrix"),
    actual_vertices = recipe(GROWTH_EXPERIMENTS[["actual_vertices"]], "actual_vertices", base = "reference-nov6", kind = "matrix"),
    prototype = recipe(GROWTH_EXPERIMENTS[["prototype"]], "prototype", flags_at(MEASURED_CAP)),
    package = recipe(GROWTH_EXPERIMENTS[["package"]], "package", probe = TRUE))
  reductions <- utils::read.csv(file.path(root, "experiments/exp_003_reductions/src/variants.csv"))$name
  for (name in reductions) specs[[name]] <- recipe("exp_003_reductions", name,
    if (name == "source_defaults") "" else flags_at(MEASURED_CAP), file.path("patches", paste0(name, ".patch")),
    probe = name == "probes_out_of_production")
  for (cap in c(MEASURED_CAP, 65536, 0)) {
    name <- sprintf("cap-%.0f", cap)
    specs[[name]] <- recipe("exp_004_worst_case", name, flags_at(cap), source_variant = "prototype")
  }
  specs$sparse <- recipe("exp_006_sparse_retention", "sparse", probe = TRUE)
  for (name in c("deletions_only", "reduced")) specs[[paste0("shorter_", name)]] <-
    recipe("exp_007_shorter_source", name, probe = TRUE, kind = "package")
  specs
}

# Query the already loaded arithmetic library without changing its thread setting.

growth_blas_runtime <- function(root, owner) {
  library <- sessionInfo()$BLAS
  version <- sub(".*-r([0-9]+[.][0-9]+[.][0-9]+)[.]dylib$", "\\1", library)
  if (version == library) stop("cannot identify the BLAS version from ", library)
  dir <- file.path(variant_work(owner), "growth-runtime")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(file.path(root, "shared/harness/blas-runtime.c"), dir, overwrite = TRUE)) stop("cannot copy runtime reader to ", dir)
  so <- file.path(dir, "blas-runtime.so")
  sh(file.path(R.home("bin"), "R"), c("CMD", "SHLIB", "-o", basename(so), "blas-runtime.c"), dir,
    result_path(owner, "logs", "growth-runtime-build.log"), env = c(PKG_LIBS = library))
  dll <- dyn.load(so)
  symbol <- getNativeSymbolInfo("loess_measure_blas_threads", PACKAGE = dll)$address
  list(library = library, version = version, threads = .C(symbol, out = integer(1))$out,
    OMP_NUM_THREADS = Sys.getenv("OMP_NUM_THREADS", unset = "<unset>"))
}

growth_builds <- function(root, labels) {
  specs <- growth_specs(root)
  unknown <- setdiff(labels, names(specs))
  if (length(unknown)) stop("unknown growth builds: ", paste(unknown, collapse = ", "))
  lapply(stats::setNames(labels, labels), function(key) {
    spec <- specs[[key]]; exp_dir <- file.path(root, "experiments", spec$experiment)
    stem <- "growth"
    dir <- file.path(variant_work(exp_dir), stem, key, "plain")
    if (spec$kind == "package") {
      helpers <- new.env(parent = globalenv())
      sys.source(file.path(exp_dir, "src/utils/packages.R"), helpers)
      package <- file.path(variant_work(exp_dir), stem, paste0("package-", spec$variant))
      helpers$copy_package(root, package)
      patch <- switch(spec$variant, deletions_only = "patches/deletions-only.patch", reduced = "variant.patch", package = NULL)
      if (!is.null(patch)) sh("patch", c("-p1", "-E", "--no-backup-if-mismatch", "-i", file.path(exp_dir, patch)), package,
        result_path(exp_dir, "logs", paste0(stem, "-", key, "-patch.log")))
      dir <- helpers$native_build(exp_dir, package, paste(stem, key, "plain", sep = "-"))
      plain <- helpers$source_wrapper(package, dir, "loessfactorpredict.so")
      probe_dir <- helpers$native_build(exp_dir, package, paste(stem, key, "probe", sep = "-"), "-DLOESS_TESTING")
      probe <- helpers$source_wrapper(package, probe_dir, "loessfactorpredict.so")
      predict <- function(data) plain$predict_se(data$fit, data$nd)
      predict_probe <- function(data) probe$predict_se(data$fit, data$nd)
    } else {
      patch <- file.path(exp_dir, spec$patch)
      prepare_variant(exp_dir, dir, base = spec$base, patch = patch,
        log = result_path(exp_dir, "logs", paste0(stem, "-", key, "-patch.log")))
      build(dir, "loessfactorpredict.so", spec$flags, result_path(exp_dir, "logs", paste0(stem, "-", key, "-build.log")))
      plain <- load_loess(dir, "loessfactorpredict.so"); probe <- NULL; probe_dir <- dir
      if (spec$needs_probe) {
        probe_dir <- file.path(dirname(dir), "probe"); copy_dir(dir, probe_dir)
        build(probe_dir, "loessfactorpredict.so", paste(spec$flags, "-DLOESS_TESTING"),
          result_path(exp_dir, "logs", paste0(stem, "-", key, "-probe-build.log")))
        probe <- load_loess(probe_dir, "loessfactorpredict.so")
      }
      predict <- function(data) plain$predict.loess(data$fit, data$nd, se = TRUE)
      predict_probe <- if (is.null(probe)) NULL else function(data) probe$predict.loess(data$fit, data$nd, se = TRUE)
    }
    c(spec, list(exp_dir = exp_dir, source_dir = dir, probe_dir = probe_dir, plain = plain, probe = probe,
      predict = predict, predict_probe = predict_probe,
      memory_method = if (spec$kind == "matrix") "source_formula" else "probe"))
  })
}
