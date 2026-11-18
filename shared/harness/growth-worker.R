# The sole entry for saved standard sweeps; the actual worker always starts in a fresh child.

main <- function(root, experiments, profile = TRUE, reference_timing = FALSE) {
  for (file in c("common.R", "variant.R", "memory.R", "growth-builds.R", "growth.R"))
    source(file.path(root, "shared/harness", file))
  specs <- growth_specs(root)
  ids <- vapply(specs, function(x) sub("^exp_([0-9]{3})_.*", "\\1", x$experiment), "")
  unknown <- setdiff(experiments, c(unique(ids), "008"))
  if (length(unknown)) stop("unknown experiments: ", paste(unknown, collapse = ", "))
  keys <- names(specs)[ids %in% experiments]
  owner <- list.files(file.path(root, "experiments"), paste0("^exp_", experiments[1], "_"), full.names = TRUE)
  if (length(owner) != 1L) stop("expected one experiment folder for ", experiments[1])
  if (profile) Rprof(result_path(owner, "profile", if (reference_timing) "r-growth.Rprof" else "growth.Rprof"))
  on.exit(if (profile) Rprof(NULL))
  if (reference_timing) return(growth_reference_timing(root))
  if (length(keys)) run_growth(root, keys)
  if ("008" %in% experiments) growth_python(root)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(TRUE)
  unknown <- args[!grepl("^--experiments=", args) & !args %in% c("--no-profile", "--reference-timing")]
  if (length(unknown)) stop("unknown argument: ", paste(unknown, collapse = " "))
  selected <- grep("^--experiments=", args, value = TRUE)
  if (length(selected) > 1L) stop("repeated --experiments: ", paste(selected, collapse = " "))
  reference_timing <- "--reference-timing" %in% args
  experiments <- if (length(selected)) strsplit(sub("^--experiments=", "", selected), ",", fixed = TRUE)[[1]] else
    if (reference_timing) "002" else sprintf("%03d", 0:8)
  if (reference_timing && !identical(experiments, "002")) stop("R reference timing belongs to experiment 002")
  self <- normalizePath(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]), fixed = TRUE))
  root <- dirname(dirname(dirname(self)))
  code <- paste0("source(", deparse(self), "); main(", deparse(root), ", ", paste(deparse(experiments), collapse = ""),
    ", profile=", !"--no-profile" %in% args, ", reference_timing=", reference_timing, ")")
  quit(status = system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)), env = "OMP_NUM_THREADS=1"))
}
