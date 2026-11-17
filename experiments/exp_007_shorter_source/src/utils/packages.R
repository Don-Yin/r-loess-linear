# Both full variants are requested comparisons; the four additions isolate their costs.

PACKAGE_VARIANTS <- c("deletions_only", "reduced")
ADDITIONS <- c("d-unified-plan", "e-shared-features", "g-blas-axpy", "p-canonical-ifit")

package_dir <- function(root, name) {
  file.path(variant_work(root), paste0("package-", if (name == "package") "source" else name))
}

library_dir <- function(root, name, cap = "default") {
  label <- if (name == "package") "source" else paste(name, cap, sep = "-")
  file.path(variant_work(root), paste0("library-", label))
}

# Every recipe is one patch on the package, or one requested addition to deletions_only.

prepare_package <- function(root, name) {
  if (name %in% ADDITIONS) {
    from <- "deletions_only"; patch <- file.path(root, "patches", paste0("add-", name, ".patch"))
  } else if (name %in% PACKAGE_VARIANTS) {
    from <- "package"
    patch <- if (name == "reduced") file.path(root, "variant.patch") else file.path(root, "patches", "deletions-only.patch")
  } else stop("unknown package recipe: ", name)
  dir <- package_dir(root, name)
  copy_dir(package_dir(root, from), dir)
  sh("patch", c("-p1", "-E", "--no-backup-if-mismatch", "-i", patch), cwd = dir,
    log = result_path(root, "logs", paste0("patch-", name, ".log")))
  dir
}

# Copy only package inputs, never the repository's experiments or generated products.

copy_package <- function(project, to) {
  unlink(to, recursive = TRUE)
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  inputs <- c("DESCRIPTION", "NAMESPACE", "R", "src", "inst", "man", "tests")
  ok <- file.copy(file.path(project, inputs), to, recursive = TRUE)
  if (!all(ok)) stop("could not copy package inputs to ", to, ": ", paste(inputs[!ok], collapse = ", "))
}

# Each build has its own installed library; compiler flags never reach the project package.

install_package <- function(root, package, label, flags = "") {
  library <- file.path(variant_work(root), paste0("library-", label))
  dir.create(library, recursive = TRUE, showWarnings = FALSE)
  sh(file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--preclean", "--no-byte-compile", paste0("--library=", library), package),
    cwd = variant_work(root), log = result_path(root, "logs", paste0("install-", label, ".log")),
    env = c(PKG_CPPFLAGS = flags))
  library
}

# Each timed method uses its own unchanged wrapper and installed native-symbol bindings.

load_packages <- function(root, names = c("package", PACKAGE_VARIANTS)) {
  stats::setNames(lapply(names, function(name) source_package(package_dir(root, name), library_dir(root, name))), names)
}

# Independent wrapper environments allow the installed libraries to be compared in one R process.

source_package <- function(package, library) {
  files <- list.files(file.path(library, "loesslin", "libs"), "\\.so$", recursive = TRUE, full.names = TRUE)
  if (length(files) != 1L) stop("expected one source package library in ", library, "; found ", length(files))
  source_wrapper(package, dirname(files), basename(files))
}

# Bind a source wrapper to exactly one library's registered symbols.

source_wrapper <- function(package, dir, so) {
  env <- list2env(c_routines(dir, so), parent = asNamespace("stats"))
  sys.source(file.path(package, "R", "predict-se.R"), env)
  env
}

# Standalone measurement libraries change only their loader name; production builds stay untouched.

native_build <- function(root, package, label, flags = "") {
  dir <- file.path(variant_work(root), label)
  copy_dir(file.path(package, "src"), dir)
  registration <- file.path(dir, "register.c")
  writeLines(sub("R_init_loesslin", "R_init_loessfactorpredict", readLines(registration)), registration)
  build(dir, "loessfactorpredict.so", flags, result_path(root, "logs", paste0("build-", label, ".log")))
  dir
}

# Reuse the harness's diff counts, and count physical lines including unchanged notices and Makevars.

source_lines <- function(original, reduced) {
  counts <- lapply(c("src", "R"), function(dir) {
    x <- line_count(file.path(reduced, dir), file.path(original, dir))
    names(x$files) <- file.path(dir, names(x$files))
    x
  })
  files <- unlist(lapply(counts, `[[`, "files"), recursive = FALSE)
  paths <- c(file.path("src", list.files(file.path(original, "src"), "\\.(c|f|h)$|^Makevars$")),
    file.path("R", "predict-se.R"))
  physical <- do.call(rbind, lapply(paths, function(path) data.frame(file = path,
    source = length(readLines(file.path(original, path), warn = FALSE)),
    reduced = length(readLines(file.path(reduced, path), warn = FALSE)))))
  added <- sum(vapply(counts, `[[`, 0, "added"))
  removed <- sum(vapply(counts, `[[`, 0, "removed"))
  list(added = added, removed = removed, saved = removed - added,
    source = sum(physical$source), reduced = sum(physical$reduced), files = files, physical = physical)
}

# Flatten native source names and map the package's prediction wrapper to R's complete loess.R.

count_against_r <- function(root, packages) {
  rows <- lapply(names(packages), function(name) {
    package <- packages[[name]]
    dir <- file.path(variant_work(root), "line-count", name)
    unlink(dir, recursive = TRUE); dir.create(dir, recursive = TRUE)
    inputs <- list.files(file.path(package, "src"), "\\.(c|f|h)$", full.names = TRUE)
    ok <- c(file.copy(inputs, dir), file.copy(file.path(package, "R", "predict-se.R"), file.path(dir, "loess.R")))
    if (!all(ok)) stop("could not prepare line-count source view: ", dir)
    lines <- line_count(dir, file.path(shared_dir(root), "reference-r"))
    adapter <- lines$files[["register.c"]]
    do.call(rbind, lapply(c("source", "register.c", "total"), function(part) {
      counts <- switch(part, source = c(lines$added - adapter$added, lines$removed - adapter$removed),
        register.c = c(adapter$added, adapter$removed), total = c(lines$added, lines$removed))
      data.frame(experiment = basename(root), variant = name, part, added = counts[1L], removed = counts[2L])
    }))
  })
  rows <- do.call(rbind, rows)
  utils::write.csv(rows, result_path(root, "tables", "lines-against-r.csv"), row.names = FALSE)
  rows
}
