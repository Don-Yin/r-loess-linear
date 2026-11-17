# worker: Rscript <this file> <geometry dir> <output csv> [profile path]
# Build real trees with the same ehg126/ehg124 calls as ehg131, without quadratic vertex fitting.
args <- commandArgs(TRUE); dir <- args[1]; out <- args[2]
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "speed.R")) source(file.path(harness, file))
start_profile(args[3])
a <- dyn.load(file.path(dir, "geometrynov6.so")); b <- dyn.load(file.path(dir, "geometrybaseline.so"))
symbol <- function(name, handle) getNativeSymbolInfo(paste0(name, "_"), handle)
build_tree <- function(x, handle) {
  n <- nrow(x); d <- ncol(x); nvmax <- ncmax <- max(200L, n); vc <- 2L^d
  box <- .Fortran(symbol("ehg126", handle), as.integer(d), as.integer(n), as.integer(vc), as.double(x),
    v = double(nvmax * d), as.integer(nvmax))$v
  corners <- integer(vc * ncmax); corners[seq_len(vc)] <- seq_len(vc)
  .Fortran(symbol("ehg124", handle), 1L, as.integer(n), d = as.integer(d), n = as.integer(n), nv = as.integer(vc), nc = 1L,
    ncmax = as.integer(ncmax), vc = as.integer(vc), x = as.double(x), pi = as.integer(seq_len(n)), a = integer(ncmax),
    xi = double(ncmax), lo = integer(ncmax), hi = integer(ncmax), c = corners, v = box, vhit = integer(nvmax),
    nvmax = as.integer(nvmax), fc = 0L, fd = 0, dd = as.integer(d))
}

# Child nodes are appended by ehg124, in increasing parent order.
tree_depth <- function(tree) {
  depth <- integer(tree$nc); depth[1] <- 1L
  for (i in seq_len(tree$nc)) if (tree$a[i] != 0L) depth[c(tree$lo[i], tree$hi[i])] <- depth[i] + 1L
  depth
}
evaluate_tree <- function(tree, handle, node) {
  # A data point assigned to the deepest leaf is inside its box, even at split boundaries.
  point <- tree$pi[tree$lo[node]]; x <- tree$x[point]
  .Fortran(symbol("ehg133", handle), d = tree$d, vc = tree$vc, nvmax = tree$nvmax, ncmax = tree$ncmax,
    a = tree$a, c = tree$c, hi = tree$hi, lo = tree$lo, v = tree$v, vval = double(2L * tree$nvmax),
    xi = tree$xi, m = 1L, z = as.double(x), result = double(1))$result
}
rows <- list(); step <- progress(4L)

# The standard ncmax = N prevents a balanced depth-20 tree until N exceeds 2^19.
for (n in c(8192L, 32768L, 131072L, 524289L)) {
  step(length(rows) + 1L, sprintf("geometry N = %d", n))
  x <- matrix(seq_len(n) / n, n)
  first <- build_tree(x, a); second <- build_tree(x, b)
  identical_tree <- same(first, second)
  if (!identical_tree) stop("geometry differs at N=", n)
  depth <- tree_depth(first); max_depth <- max(depth); node <- which(depth == max_depth & first$a[seq_len(first$nc)] == 0L)[1]
  ea <- capture(evaluate_tree(first, a, node)); eb <- capture(evaluate_tree(second, b, node))
  identical_out <- identical_tree && same(ea, eb) && !inherits(ea$value, "error-message")
  if (!identical_out) stop("deepest interpolation differs at N=", n)
  ta <- user_seconds(build_tree(x, a)); tb <- user_seconds(build_tree(x, b))
  arrays <- 4 * ((2^1 + 3) * n + n + n) + 8 * (n + n)
  rows[[length(rows) + 1L]] <- data.frame(n, max_depth, depth_20_reached = max_depth >= 20,
    vertices = first$nv, cells = first$nc, identical = identical_out, warning_count = length(ea$warnings),
    depth_warning_count = sum(ea$warnings == "nt>20 in eval."), nov6_s = ta, baseline_s = tb, ratio = tb / ta,
    native_array_bytes = arrays)
  write.csv(do.call(rbind, rows), out, row.names = FALSE)
  rm(first, second); gc(FALSE)
}
print(do.call(rbind, rows), row.names = FALSE)
Rprof(NULL)
