# Compare the one-predictor diagnostic fallback directly after the shared measurements.
verify_diagnostics <- function(root, profile = TRUE, name = NULL) {
  work <- variant_work(root, name)
  output <- result_path(root, "tables", "diagnostics.csv", name)
  worker(root, file.path(root, "src", "modules", "diagnostics.R"),
    c(file.path(work, "src"), file.path(work, "reference-nov6"), output), "diagnostics", profile, name)
  rows <- utils::read.csv(output)
  data.frame(suite = "one-predictor-diagnostics",
    identical = sum(rows$matrix_identical & rows$warnings_identical), cases = nrow(rows))
}
