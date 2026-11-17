# Compare the trimmed routines directly with the original branches.
verify_qr <- function(root, profile = TRUE, name = NULL) {
  work <- file.path(variant_work(root, name), "qr-edge-cases")
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  routines <- c("dqrdcx.f" = "refqrd", "dqrslx.f" = "refqsl")
  for (file in names(routines)) {
    source <- readLines(file.path(shared_dir(root), "baseline", file), warn = FALSE)
    writeLines(sub("subroutine [[:alnum:]_]+\\(", paste0("subroutine ", routines[[file]], "("), source), file.path(work, file))
  }
  copied <- file.copy(file.path(variant_work(root, name), "src", "captured-qr.f"), file.path(work, "captured-qr.f"), overwrite = TRUE)
  if (!copied) stop("could not copy captured QR source to ", work, call. = FALSE)
  build(work, "qr-check.so", "", result_path(root, "logs", "qr-edge-build.log", name))
  output <- result_path(root, "json", "qr-edge-cases.json", name)
  worker(root, file.path(root, "src", "modules", "qr-edge-cases.R"),
    c(work, output), "qr-edge-check", profile, name)
  counts <- jsonlite::read_json(output)
  data.frame(suite = "qr-edge-cases", identical = counts$identical, cases = counts$cases)
}
