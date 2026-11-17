# Arguments: observation count, result directory, profile path (empty disables profiling).

reference <- function(n, out) {
  source(file.path("..", "..", "shared", "harness", "common.R"))
  z <- toby_data(n)
  if (!identical(z$fit$pars$trace.hat, "exact")) stop("R trace.hat is not exact: ", z$fit$pars$trace.hat)
  writeBin(as.double(c(z$fit$x, z$fit$y, z$nd$x)), file.path(out, "data", paste0("input-", n, ".bin")), endian = "little")
  values <- as.double(predict(z$fit, z$nd))
  status <- "ok"
  error <- ""
  se <- tryCatch(as.double(predict(z$fit, z$nd, se = TRUE)$se.fit), error = function(e) {
    status <<- "workspace-error"
    error <<- conditionMessage(e)
    rep(NA_real_, nrow(z$nd))
  })
  expected_error <- n >= 46337L
  if (identical(status, "workspace-error") != expected_error || (expected_error && !grepl("workspace required", error, fixed = TRUE))) {
    stop("unexpected R SE status for n=", n, ": ", status, " ", error)
  }
  writeBin(as.double(c(z$fit$fitted, values, se)), file.path(out, "data", paste0("r-reference-", n, ".bin")), endian = "little")
  meta <- list(n = n, m = nrow(z$nd), span = 0.5, degree = 2L, cell = z$fit$pars$cell,
               trace_hat = z$fit$pars$trace.hat, family = z$fit$pars$family,
               vertices = z$fit$kd$parameter[[5L]], status = status, error = error,
               residual_scale = z$fit$s, df = z$fit$one.delta^2 / z$fit$two.delta,
               r_version = as.character(getRversion()))
  jsonlite::write_json(meta, file.path(out, "json", paste0("r-n", n, ".json")), auto_unbox = TRUE, pretty = TRUE, digits = NA)
  message("reference n=", n, " vertices=", meta$vertices, " status=", status)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  n <- as.integer(args[[1L]])
  if (is.na(n) || n < 32L) stop("invalid observation count: ", args[[1L]])
  if (nzchar(args[[3L]])) {
    Rprof(args[[3L]])
    tryCatch(reference(n, args[[2L]]), finally = Rprof(NULL))
  } else {
    reference(n, args[[2L]])
  }
}
