# Thin entry for actual-vertex coefficient storage compared with R.

main <- function(root, profile = TRUE) {
  for (file in c("common.R", "variant.R", "matrix.R")) source(file.path(root, "..", "..", "shared", "harness", file))
  run_matrix_variant(root, compact = TRUE, profile = profile)
}

# source() defines main without starting work or profiling; workers receive their own profile paths.

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  unknown <- setdiff(args, "--no-profile")
  if (length(unknown)) stop("unknown argument: ", paste(unknown, collapse = " "))
  file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
  root <- dirname(normalizePath(gsub("~+~", " ", file, fixed = TRUE)))
  if ("--no-profile" %in% args) {
    invisible(main(root, profile = FALSE))
  } else {
    profile <- file.path(root, ".results", "profile")
    dir.create(profile, recursive = TRUE, showWarnings = FALSE)
    Rprof(file.path(profile, "run.Rprof"))
    invisible(tryCatch(main(root), finally = Rprof(NULL)))
  }
}
