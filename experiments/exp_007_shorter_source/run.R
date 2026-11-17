# Thin entry for exp_007_shorter_source: reduce a private package copy and compare it with its source.

main <- function(root, profile = TRUE) {
  for (file in c("common.R", "variant.R"))
    source(file.path(root, "..", "..", "shared", "harness", file))
  source(file.path(root, "src", "utils", "packages.R"))
  source(file.path(root, "src", "modules", "orchestration.R"))
  message("writing outputs to ", file.path(root, ".results"))
  measure(root, profile)
}

# source() defines functions only; each worker profiles its own actual work.

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
