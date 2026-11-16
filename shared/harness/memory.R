# Memory: bytes each predict call requests. A build reports its own native request through its probes after
# the call; R and the Nov 6 patch request a workspace fixed by their sources (loess_workspace in loessc.c),
# computed here. source() this file; it defines functions only.

# The build's probe readings after its last call, by name; NA where the build has no probes.
probe_values <- function(routines) {
  read <- function(name, size, at)
    if (is.null(routines[[name]])) rep(NA_real_, length(at)) else .C(routines[[name]], out = double(size))$out[at]
  values <- c(read("C_loess_probe", 20, c(4, 5, 12, 15, 20)), read("C_loess_retention_probe", 4, 2:3),
    read("C_loess_exception_probe", 3, 1:3))
  as.list(stats::setNames(values, c("neighborhood_rows", "vertices", "diagnostic_calls", "native_bytes",
    "needed_vertices", "retained_vertices", "retained_bytes", "zero_radius_vertices",
    "unretained_exceptional_vertices", "replay_vertex_fits")))
}

# Lengths of the double (lv) and integer (liv) workspace R allocates for d predictors and n observations.
reference_workspace <- function(d, n, span, degree) {
  nvmax <- max(200, n); nf <- min(n, floor(n * span + 1e-5))
  tau <- if (degree > 1) (d + 2) * (d + 1) / 2 else d + 1
  c(lv = 50 + (3 * d + 3) * nvmax + n + (tau + 2) * nf + (d + 1) * nf * nvmax,
    liv = 50 + (2^d + 4) * nvmax + 2 * n + nf * nvmax)
}

# Bytes requested for one call: the C workspace (native; nv = 0 for R, the fit's vertex count for the Nov 6
# patch, which adds an N by nv cache) and the N by M matrix the Nov 6 patch returns (L).
reference_bytes <- function(d, n, m, span, degree, nv) {
  w <- reference_workspace(d, n, span, degree)
  c(native = 8 * w[["lv"]] + 4 * w[["liv"]] + 4 * nv * n, L = 8 * n * m)
}

# First n whose double workspace no longer fits R's integer length, where R's predict stops.
reference_first_invalid_n <- function(d, span, degree) {
  fits <- function(n) reference_workspace(d, n, span, degree)[["lv"]] < .Machine$integer.max
  high <- 1; while (fits(high)) high <- 2 * high
  low <- high / 2
  while (high - low > 1) { middle <- floor((low + high) / 2); if (fits(middle)) low <- middle else high <- middle }
  high
}
