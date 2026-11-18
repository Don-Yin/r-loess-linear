# Verify saved standard summaries against their raw observations and strict-output boundary.

check_growth <- function(root, scratch) {
  for (file in c("common.R", "variant.R", "memory.R", "growth-builds.R", "growth.R"))
    source(file.path(root, "shared/harness", file))
  dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
  reference <- growth_reference(root)
  stopifnot(!is.null(reference))
  path <- file.path(scratch, "roundtrip.rds")
  saveRDS(reference$predictions, path)
  stopifnot(same(reference$predictions, readRDS(path)))
  experiments <- unique(c(vapply(growth_specs(root), `[[`, "", "experiment"), "exp_008_python_skmisc"))
  for (experiment in experiments) {
    owner <- file.path(root, "experiments", experiment)
    rows <- utils::read.csv(file.path(owner, ".results/tables/growth.csv"))
    raw <- utils::read.csv(file.path(owner, ".results/tables/growth-rounds.csv"))
    identity <- if (experiment == "exp_008_python_skmisc") "identical_to_reference" else "identical_to_r"
    stopifnot(all(rows[[identity]]), all(rows$memory_method %in% c("probe", "source_formula", "allocation_trace")))
    for (name in unique(rows$build)) stopifnot(identical(rows$N[rows$build == name], growth_sizes()))
    for (i in seq_len(nrow(rows))) {
      r <- rows[i, ]; s <- raw$seconds[raw$build == r$build & raw$N == r$N]
      expected <- c(length(s), median(s), min(s), max(s), sd(s))
      actual <- unlist(r[c("repetitions", "median_seconds", "min_seconds", "max_seconds", "sd_seconds")])
      stopifnot(isTRUE(all.equal(unname(actual), expected, tolerance = 1e-12)))
    }
  }
  changed <- reference$predictions[[1]]; changed$value$se.fit[1] <- changed$value$se.fit[1] + 1
  out <- file.path(scratch, "growth.csv")
  failed <- tryCatch({ growth_exact(reference$predictions[[1]], changed, "regression", 100L, out); FALSE }, error = function(e) TRUE)
  stopifnot(failed, file.exists(sub("[.]csv$", "-regression-n100-failure.rds", out)))
  message("growth checks pass: artifact, every saved summary, grids, identity flags and mismatch exit")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(TRUE)
  if (length(args) != 1L) stop("expected one disposable scratch directory; got: ", paste(args, collapse = " "))
  self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
  root <- dirname(dirname(dirname(normalizePath(gsub("~+~", " ", self, fixed = TRUE)))))
  profile <- file.path(root, "experiments/exp_002_baseline_prototype/.results/profile/growth-check.Rprof")
  dir.create(dirname(profile), recursive = TRUE, showWarnings = FALSE)
  Rprof(profile)
  invisible(tryCatch(check_growth(root, args[1]), finally = Rprof(NULL)))
}
