# Tied-input stress cases and their measurement, used by exp_002, exp_003 and exp_004. source() after common.R, speed.R
# and memory.R; functions only.

# Deterministic tied inputs; the same cases feed every retention cap.
measurement_cases <- function() {
  rows <- list()
  for (family in c("spike-cloud", "repeated-grid", "grid-cloud")) {
    for (d in 2:4) for (n in if (family == "grid-cloud") 8192L else c(4096L, 8192L)) {
      rows[[length(rows) + 1L]] <- data.frame(
        id = paste(family, d, n, sep = "-"), family, d, n, m = 512L,
        span = if (family == "spike-cloud") .2 else if (family == "repeated-grid") .0039 else .0019,
        cell = if (family == "grid-cloud") .001 else .005,
        seed = 20261111L, stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}

# Keep complete tied rows, not merely marginal ties, and cover all grid sites in prediction.
case_input <- function(cs) {
  set.seed(cs$seed)
  n <- cs$n; d <- cs$d
  levels <- c(16L, 6L, 4L)[d - 1L]
  if (cs$family == "spike-cloud") {
    X <- rbind(matrix(.5, n / 2L, d), matrix(runif(n / 2L * d, 1, 3), n / 2L, d))
    sites <- matrix(.5, 1L, d); tied_n <- n / 2L
  } else {
    sites <- as.matrix(expand.grid(rep(list(seq_len(levels)), d)))
    tied_n <- if (cs$family == "repeated-grid") n else n / 2L
    X <- sites[rep(seq_len(nrow(sites)), length.out = tied_n), , drop = FALSE]
    if (cs$family == "grid-cloud")
      X <- rbind(X, matrix(runif((n - tied_n) * d, .5, levels + .5), n - tied_n, d))
  }
  colnames(X) <- paste0("x", seq_len(d))
  nd <- rbind(sites, X[unique(round(seq(1, n, length.out = cs$m))), , drop = FALSE])
  nd <- nd[!duplicated(as.data.frame(nd)), , drop = FALSE]
  if (nrow(nd) > cs$m) nd <- nd[seq_len(cs$m), , drop = FALSE]
  colnames(nd) <- colnames(X)
  y <- rowSums(sin(X)) + rnorm(n, sd = .35)
  list(X = X, y = y, nd = as.data.frame(nd), unique_rows = nrow(unique(as.data.frame(X))),
    tied_rows = tied_n, tied_sites = nrow(sites), min_tie_multiplicity = floor(tied_n / nrow(sites)))
}

# Check public diagnostics, native variance and every coefficient of the operator matrix before timing.
measure_case <- function(cs, new, nov6, cap, results) {
  input <- case_input(cs); X <- input$X; n <- nrow(X); d <- ncol(X); m <- nrow(input$nd)
  df <- data.frame(X, y = input$y)
  formula <- reformulate(colnames(X), response = "y")
  fitted <- capture(stats::loess(formula, df, span = cs$span, control = loess.control(cell = cs$cell)))
  if (inherits(fitted$value, "error-message")) stop("fit failed for ", cs$id, ": ", fitted$value)
  pa <- capture(nov6$predict.loess(fitted$value, input$nd, se = TRUE, cache = TRUE))
  pb <- capture(new$predict.loess(fitted$value, input$nd, se = TRUE))
  predict_a <- function() native_se(nov6, X, input$y, input$nd, cs, FALSE)
  predict_b <- function() native_se(new, X, input$y, input$nd, cs, TRUE)
  a <- capture(predict_a()); b <- capture(predict_b())
  ma <- capture(native_matrix(nov6, X, input$y, input$nd, cs, FALSE))
  mb <- capture(native_matrix(new, X, input$y, input$nd, cs, TRUE))
  public_identical <- same(pa, pb)
  native_identical <- same(a, b) && !inherits(a$value, "error-message")
  matrix_identical <- same(ma, mb) && !inherits(ma$value, "error-message")
  identical_out <- public_identical && native_identical && matrix_identical
  saveRDS(list(case = cs, fit_warnings = fitted$warnings, nov6 = pa, baseline = pb),
    file.path(results, "diagnostics", paste0(cs$id, "-cap-", cap, "-public.rds")))
  if (!identical_out) {
    failure <- file.path(results, "diagnostics", paste0(cs$id, "-cap-", cap, "-failure.rds"))
    saveRDS(list(case = cs, public = list(pa, pb), variance = list(a, b), matrix = list(ma, mb)), failure)
    stop("exactness failed for ", cs$id, " at cap ", cap, "; see ", failure)
  }
  p <- probe_values(new)
  bytes <- reference_bytes(d, n, m, cs$span, 2, p$vertices)
  s <- interleaved_seconds(list(nov6 = predict_a, baseline = predict_b), 3L)
  saveRDS(list(case = cs, cap_bytes = cap, user_seconds = attr(s, "rounds")),
    file.path(results, "diagnostics", paste0(cs$id, "-cap-", cap, "-timing.rds")))
  data.frame(id = cs$id, family = cs$family, cap_bytes = cap, d, n, m, span = cs$span, cell = cs$cell,
    seed = cs$seed, neighborhood_rows = p$neighborhood_rows, unique_rows = input$unique_rows,
    tied_rows = input$tied_rows, tied_sites = input$tied_sites, min_tie_multiplicity = input$min_tie_multiplicity,
    identical = identical_out, public_identical, native_identical, matrix_identical,
    public_error = inherits(pa$value, "error-message"), public_warning_count = length(pa$warnings),
    warning_count = length(a$warnings), nan_variances = sum(is.nan(a$value)),
    nov6_s = s[["nov6"]], baseline_s = s[["baseline"]], ratio = s[["baseline"]] / s[["nov6"]],
    baseline_native_bytes = p$native_bytes, nov6_native_bytes = bytes[["native"]],
    nov6_L_bytes = bytes[["L"]], nov6_native_and_L_bytes = sum(bytes),
    vertices = p$vertices, needed_vertices = p$needed_vertices, retention_slots = floor(cap / (8 * (d + 1) * n)),
    p[c("retained_vertices", "retained_bytes", "zero_radius_vertices", "unretained_exceptional_vertices",
      "replay_vertex_fits")])
}

# Confirm that exceptional losses are zero-radius records using the same case at a zero cap.
classify_zero_radius <- function(row, controls) {
  control <- controls[controls$id == row$id, , drop = FALSE]
  proved <- nrow(control) == 1L && control$zero_radius_vertices == control$unretained_exceptional_vertices &&
    control$zero_radius_vertices == row$zero_radius_vertices && control$needed_vertices == row$needed_vertices
  unretained <- if (row$unretained_exceptional_vertices == 0) 0 else
    if (proved) row$unretained_exceptional_vertices else NA_real_
  c(row, list(unretained_zero_radius_vertices = unretained,
    retained_zero_radius_vertices = row$zero_radius_vertices - unretained,
    exceptional_zero_radius_confirmed = proved))
}
