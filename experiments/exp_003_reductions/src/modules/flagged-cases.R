# worker: Rscript <this file> <baseline dir> <variant dir> <geometry dir> <checks csv> <geometry csv> <timing csv> [profile path]
# Compare flagged native calls with the unchanged prototype and search real tree geometry.
# `cell` is the value the native entry takes, span * cell in the terms of loess.control().
args <- commandArgs(TRUE)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "speed.R", "memory.R")) source(file.path(harness, file))
start_profile(args[7])
base <- c_routines(args[1], "loessfactorpredict.so"); variant <- c_routines(args[2], "loessfactorpredict.so")
geometry <- getDLLRegisteredRoutines(dyn.load(file.path(args[3], "geometrycheck.so")))$.Fortran
plan <- function(x, z, span, degree, cell) {
  n <- nrow(x); d <- ncol(x); m <- nrow(z); nvmax <- max(200L, n)
  nf <- min(n, floor(n * span + 1e-5)); tau <- if (degree > 1) (d + 2) * (d + 1) / 2 else d + 1
  lv <- as.integer(50 + (3 * d + 3) * nvmax + n + (tau + 2) * nf)
  liv <- as.integer(50 + (2^d + 4) * nvmax + 2 * n)
  init <- .Fortran(geometry$lowesd, iv = integer(liv), liv, lv, wv = double(lv), as.integer(d),
    as.integer(n), span, as.integer(degree), as.integer(nf), as.integer(nvmax), 0L)
  init$iv[33] <- as.integer(d); init$iv[seq.int(41, 40 + d)] <- 2L; init$wv[2] <- cell
  tree <- .Fortran(geometry$lowesv, as.double(x), iv = init$iv, wv = init$wv)
  p <- .Fortran(geometry$lowesfnp, tree$iv, tree$wv, as.integer(m), as.double(z),
    ids = integer(2^d * m), double(5 * d * m), integer(8 * m), double(20 * m), diag = integer(m), NAOK = TRUE)
  iv <- tree$iv; wv <- tree$wv
  depths <- vapply(seq_len(m), function(i) {
    j <- 1L; depth <- 1L
    while (iv[iv[7] + j - 1L] != 0L) {
      axis <- iv[iv[7] + j - 1L]
      offset <- if (z[i, axis] <= wv[iv[12] + j - 1L]) iv[10] else iv[9]
      j <- iv[offset + j - 1L]; depth <- depth + 1L
    }
    depth
  }, integer(1))
  vertices <- matrix(wv[seq.int(iv[11], length.out = nvmax * d)], nvmax, d)
  ids <- matrix(p$ids, 2^d, m)
  widths <- vertices[ids[2^d, ], , drop = FALSE] - vertices[ids[1, ], , drop = FALSE]
  list(flagged = sum(p$diag != 0L), depth = max(depths), nv = iv[6],
    zero_widths = sum(widths == 0, na.rm = TRUE), nonfinite_widths = sum(!is.finite(widths)))
}

native <- function(routines, x, z, degree, span, cell) {
  answer <- capture(native_call(routines$C_loess_factor_L, x, sin(x[, 1]), z, span, cell, degree, nrow(x) * nrow(z)))
  list(answer = answer, probe = probe_values(routines))
}

checks <- list(); searches <- list(); step <- progress(5L)
record_search <- function(id, x, z, span, degree, cell) {
  p <- plan(x, z, span, degree, cell)
  searches[[length(searches) + 1L]] <<- data.frame(id, d = ncol(x), n = nrow(x), m = nrow(z),
    flagged_points = p$flagged, max_query_depth = p$depth, vertices = p$nv,
    zero_widths = p$zero_widths, nonfinite_widths = p$nonfinite_widths)
  p
}
record_check <- function(id, x, z, degree, cell) {
  p <- record_search(id, x, z, .8, degree, cell)
  a <- native(base, x, z, degree, .8, cell); b <- native(variant, x, z, degree, .8, cell)
  checks[[length(checks) + 1L]] <<- data.frame(id, d = ncol(x), n = nrow(x), m = nrow(z), degree, cell,
    flagged_points = p$flagged, matrix_identical = same(a$answer$value, b$answer$value),
    warnings_identical = same(a$answer$warnings, b$answer$warnings),
    returned_matrix = !inherits(b$answer$value, "error-message"), warnings = length(b$answer$warnings),
    baseline_needed = a$probe$needed_vertices, variant_needed = b$probe$needed_vertices, vertices = b$probe$vertices,
    baseline_bytes = a$probe$native_bytes, variant_bytes = b$probe$native_bytes)
}
step(1L, "points outside the data range")
for (d in 1:4) for (degree in 1:2) for (cell in c(0, .15)) {
  set.seed(600 + d); x <- matrix(runif(192 * d, -1, 1), 192, d)
  z <- rbind(rep(-1.5, d), rep(.1, d), rep(1.5, d))
  record_check(paste("outside", d, degree, cell, sep = "-"), x, z, degree, cell)
}

# Finite in-range data with ties, a constant axis, tiny cells and near-machine-limit scales.
step(2L, "tied and extreme geometry"); set.seed(606)
for (scenario in c("rounded", "constant-axis", "block-ties", "tiny-scale", "large-offset", "overflow-width")) {
  x <- switch(scenario,
    rounded = matrix(round(runif(256, -2, 2)), 128, 2),
    `constant-axis` = cbind(runif(128), rep(1, 128)),
    `block-ties` = cbind(c(rep(0, 96), seq(1, 2, length.out = 32)), round(runif(128))),
    `tiny-scale` = matrix(runif(256, -1, 1) * 1e-300, 128, 2),
    `large-offset` = 1e150 + matrix(runif(256, -1, 1) * 1e136, 128, 2),
    `overflow-width` = matrix(rep(c(-1e308, 1e308), 128), 128, 2))
  z <- x[c(1, 32, 64, 96, 128), , drop = FALSE]
  record_search(scenario, x, z, .8, 1L, 0)
}

# Complete native calls for an in-range overflow geometry, including warning order.
step(3L, "overflow geometry")
x <- matrix(rep(c(-1e308, 1e308), 128), 128, 2)
z <- x[c(1, 32, 64, 96, 128), , drop = FALSE]
for (degree in 1:2) record_check(paste0("overflow-width-degree", degree), x, z, degree, 0)

# Larger balanced grids test depth 20 without the quadratic-cost vertex producer.
step(4L, "deep grids")
for (ny in c(512L, 1024L)) {
  nx <- 1024L
  x <- cbind(rep(seq(-1, 1, length.out = nx), ny), rep(seq(-1, 1, length.out = ny), each = nx))
  z <- x[c(1, nx, nrow(x) - nx + 1L, nrow(x)), , drop = FALSE]
  invisible(record_search(paste0("deep-grid-", nrow(x)), x, z, 16 / nrow(x), 1L, 0))
  rm(x); invisible(gc())
}

# User CPU and native allocation on a flagged native call, interleaved with the unchanged prototype.
step(5L, "timing"); set.seed(607); x <- matrix(runif(4000, -3, 3), 2000, 2); z <- rbind(c(-4, -4), c(0, 0))
a <- native(base, x, z, 2L, .75, .025); b <- native(variant, x, z, 2L, .75, .025)
s <- interleaved_seconds(list(baseline = function() native(base, x, z, 2L, .75, .025),
  variant = function() native(variant, x, z, 2L, .75, .025)), 5L)
timing <- data.frame(id = "outside-d2-n2000-m2-cell0.025", baseline_s = s[["baseline"]], variant_s = s[["variant"]],
  ratio_to_baseline = s[["variant"]] / s[["baseline"]], baseline_needed = a$probe$needed_vertices,
  variant_needed = b$probe$needed_vertices, vertices = b$probe$vertices,
  baseline_bytes = a$probe$native_bytes, variant_bytes = b$probe$native_bytes,
  matrix_identical = same(a$answer$value, b$answer$value) && !inherits(a$answer$value, "error-message"), warnings_identical = same(a$answer$warnings, b$answer$warnings))
checks <- do.call(rbind, checks); searches <- do.call(rbind, searches)
write.csv(checks, args[4], row.names = FALSE)
write.csv(searches, args[5], row.names = FALSE)
write.csv(timing, args[6], row.names = FALSE)
if (!all(checks$matrix_identical & checks$warnings_identical & checks$returned_matrix) ||
    !timing$matrix_identical || !timing$warnings_identical ||
    !all(checks$variant_needed == checks$vertices) ||
    !any(searches$id == "deep-grid-1048576" & searches$max_query_depth >= 20 & searches$flagged_points > 0) ||
    !any(searches$id == "overflow-width" & searches$flagged_points > 0 & searches$nonfinite_widths > 0)) {
  stop("flagged-path checks failed: ", args[4], "; ", args[5], "; ", args[6])
}
Rprof(NULL)
