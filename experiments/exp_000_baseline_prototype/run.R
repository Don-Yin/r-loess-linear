# Thin entry for exp_000_baseline_prototype: the prototype sources as measured, no patch.

main <- function(root, profile = TRUE) {
  for (file in c("common.R", "variant.R")) source(file.path(root, "..", "..", "shared", "harness", file))
  message("writing outputs to ", file.path(root, ".results"))
  summary <- run_variant(root, profile = profile)

  # native bytes against R's workspace over N in Toby's setup
  table <- result_path(root, "tables", "memory.csv")
  worker(root, file.path(root, "src", "modules", "memory-sweep.R"), c(file.path(variant_work(root), "src"), table), "memory", profile)
  summary$memory <- utils::read.csv(table)

  # R's own predict(se = TRUE), unpatched, in the nine timing cases
  table <- result_path(root, "tables", "r-timing.csv")
  worker(root, file.path(root, "src", "modules", "r-timing.R"), table, "r-timing", profile)
  summary$r_timing <- utils::read.csv(table)
  write_json(summary, result_path(root, "json", "summary.json"))
  summary
}

# source() never starts work or profiling; only `Rscript run.R` does.
# Rprof here covers the orchestration; each worker process writes its own profile beside it.
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
