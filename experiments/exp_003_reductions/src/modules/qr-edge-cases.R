# worker: Rscript <this file> <QR build dir> <output json> [profile path]
args <- commandArgs(TRUE)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
source(file.path(harness, "common.R"))
start_profile(args[3])
dyn.load(file.path(args[1], "qr-check.so"))
rows <- list()
add <- function(id, ok) rows[[length(rows) + 1L]] <<- data.frame(id, ok)
set.seed(904)
for (shape in list(c(1L, 1L), c(2L, 1L), c(2L, 2L), c(7L, 3L), c(30L, 15L))) {
  n <- shape[1]; p <- shape[2]; ldx <- n + 2L
  for (kind in c("dense", "zero", "zero-first", "zero-last", "dependent")) {
    x <- matrix(rnorm(ldx * p), ldx, p)
    if (kind == "zero") x[seq_len(n), ] <- 0
    if (kind == "zero-first") x[seq_len(n), 1] <- 0
    if (kind == "zero-last") x[seq_len(n), p] <- 0
    if (kind == "dependent" && p > 1L) x[seq_len(n), p] <- x[seq_len(n), 1]
    a <- .Fortran("refqrd", x = as.double(x), ldx, n, p, qraux = rep(13, 15),
      integer(p), double(p), 0L, alphas = rep(13, 15), qrts = rep(13, 225))
    b <- .Fortran("dqrdcx", x = as.double(x), ldx, n, p, qraux = rep(13, 15),
      alphas = rep(13, 15), qrts = rep(13, 225))
    id <- paste(n, p, kind, sep = "-")
    add(paste(id, "qr", sep = "-"), all(vapply(c("x", "qraux", "alphas", "qrts"),
      function(key) same(a[[key]], b[[key]]), logical(1))))
    for (vector in c("dense", "zero")) {
      y <- if (vector == "zero") double(n) else rnorm(n)
      qa <- .Fortran("refqsl", x = a$x, ldx, n, p, qraux = a$qraux, y,
        qy = rep(13, n), double(n), double(p), double(n), double(n), 10000L,
        info = 13L, ts = rep(13, 15))
      qb <- .Fortran("dqrslx", x = b$x, ldx, n, p, qraux = b$qraux, y,
        qy = rep(13, n), ts = rep(13, 15))
      add(paste(id, vector, "qy", sep = "-"), qa$info == 0L &&
        all(vapply(c("x", "qraux", "qy", "ts"),
          function(key) same(qa[[key]], qb[[key]]), logical(1))))
    }
  }
}
r <- do.call(rbind, rows)
write_json(list(cases = nrow(r), identical = sum(r$ok)), args[2])
print(r, row.names = FALSE)
cat("qr edge cases", sum(r$ok), "/", nrow(r), "identical\n")
Rprof(NULL)
if (!all(r$ok)) stop("trimmed QR differs from the original branches: ", args[2])
