# Recount source changes against original R and stop when the README column is stale.

line_range <- function(values) {
  limits <- range(values)
  shown <- format(limits, big.mark = ",", scientific = FALSE, trim = TRUE)
  if (limits[1] == limits[2]) shown[1] else paste(shown, collapse = "–")
}

recount_shorter <- function(root) {
  experiment <- file.path(root, "experiments", "exp_007_shorter_source")
  helpers <- new.env(parent = globalenv())
  sys.source(file.path(experiment, "src", "utils", "packages.R"), helpers)
  work <- file.path(variant_work(experiment), "readme-line-check")
  original <- file.path(work, "package"); candidate <- file.path(work, "deletions_only")
  helpers$copy_package(root, original)
  copy_dir(original, candidate)
  sh("patch", c("-p1", "-E", "--no-backup-if-mismatch", "-i", file.path(experiment, "patches", "deletions-only.patch")),
    cwd = candidate, log = result_path(experiment, "logs", "readme-line-check.log"))
  flat <- file.path(work, "flat"); unlink(flat, recursive = TRUE); dir.create(flat, recursive = TRUE)
  files <- list.files(file.path(candidate, "src"), "\\.(c|f|h)$", full.names = TRUE)
  copied <- c(file.copy(files, flat), file.copy(file.path(candidate, "R", "predict-se.R"), file.path(flat, "loess.R")))
  if (!all(copied)) stop("could not prepare source count in ", flat)
  counts <- line_count(flat, file.path(root, "shared", "reference-r"))
  adapter <- counts$files[["register.c"]]
  data.frame(variant = "deletions_only", part = "source",
    added = counts$added - adapter$added, removed = counts$removed - adapter$removed)
}

check_lines <- function(root, readme = file.path(root, "README.md")) {
  counter <- new.env(parent = globalenv())
  sys.source(file.path(root, "shared", "harness", "lines.R"), counter)
  invisible(capture.output(counter$main(root)))
  variants <- list(
    exp_000_nov6_cache = "cache", exp_001_actual_vertices = "actual_vertices",
    exp_002_baseline_prototype = "prototype", exp_003_reductions = NULL,
    exp_004_worst_case = "prototype", exp_005_package_source = "package",
    exp_006_sparse_retention = "sparse")
  text <- readLines(readme, warn = FALSE)
  if (any(grepl("](experiments/exp_007_shorter_source/README.md)", text, fixed = TRUE))) {
    variants$exp_007_shorter_source <- "deletions_only"
  }
  split_row <- function(row) trimws(strsplit(row, "|", fixed = TRUE)[[1]])[-1L]
  # Only the table counted against original R; the Python table counts against scikit-misc.

  header <- which(vapply(text, function(line) "source lines against&nbsp;R" %in% split_row(line), NA))
  if (length(header) != 1L) stop("expected one table with a source lines against R column in ", readme)
  column <- match("source lines against&nbsp;R", split_row(text[header]))
  after <- text[-seq_len(header)]
  table <- after[seq_len(match(FALSE, startsWith(after, "|"), nomatch = length(after) + 1L) - 1L)]
  rows <- grep("^\\| \\[exp_[0-9]{3} ", table, value = TRUE)
  experiments <- vapply(rows, function(row) {
    sub(".*\\]\\(experiments/([^/]+)/README\\.md\\).*", "\\1", split_row(row)[1])
  }, "")
  if (!identical(unname(experiments), names(variants))) {
    stop("experiment rows in ", readme, " are ", paste(experiments, collapse = ", "),
      "; expected ", paste(names(variants), collapse = ", "))
  }
  for (i in seq_along(experiments)) {
    experiment <- experiments[i]
    path <- file.path(root, "experiments", experiment, ".results", "tables", "lines-against-r.csv")
    counts <- if (experiment == "exp_007_shorter_source") recount_shorter(root) else utils::read.csv(path)
    counts <- counts[counts$part == "source", ]
    selected <- variants[[experiment]]
    if (!is.null(selected)) counts <- counts[counts$variant == selected, ]
    if (!nrow(counts) || anyNA(counts[c("added", "removed")])) stop("missing source counts in ", path)
    expected <- paste0("+", line_range(counts$added), " / −", line_range(counts$removed))
    actual <- gsub("&nbsp;", " ", split_row(rows[i])[column], fixed = TRUE)
    if (!identical(actual, expected)) {
      stop("stale source lines for ", experiment, " in ", readme, ": found '", actual,
        "', recounted '", expected, "' from ", path, call. = FALSE)
    }
    message(experiment, ": ", expected)
  }
  message("README source line column agrees with original-R recount")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(TRUE)
  if (length(args)) stop("unknown argument: ", paste(args, collapse = " "))
  file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
  root <- dirname(dirname(dirname(normalizePath(gsub("~+~", " ", file, fixed = TRUE)))))
  check_lines(root)
}
