# Unpatched R on the tied inputs of the result figures: Rscript docs/figures/result/r-tied.R, from the
# repository root; about 20 minutes. Writes r-tied.json beside this file. The experiments do not run R on
# these inputs, so it is measured here, by input: its own native routine (three runs), the workspace it
# requests, and whether its result is the package source's bit for bit.

# Needs exp_005's build: Rscript experiments/exp_005_package_source/run.R.

for (file in c("common.R", "speed.R", "memory.R", "tied.R")) source(file.path("shared", "harness", file))
package <- load_loess(file.path("experiments", "exp_005_package_source", ".intermediates", "probe-cap-67108864"),
  "loessfactorpredict.so")

r_measured <- function(X, y, nd, cs) {
  r <- function() suppressWarnings(r_native_se(X, y, nd, cs))
  list(identical = same(r(), suppressWarnings(native_se(package, X, y, nd, cs, TRUE))),
    seconds = interleaved_seconds(list(r = r), 3L)[["r"]],
    bytes = reference_bytes(ncol(X), nrow(X), nrow(as.matrix(nd)), cs$span, 2, 0)[["native"]])
}

cases <- measurement_cases(); step <- progress(nrow(cases))
r <- lapply(setNames(seq_len(nrow(cases)), cases$id), function(i) {
  cs <- cases[i, ]; step(i, cs$id); input <- case_input(cs)
  r_measured(input$X, input$y, input$nd, cs)
})

# the zero-radius input of exp_004 (stress.R): one predictor, half of x tied at one point

cs <- list(span = 0.2, cell = 0.2); set.seed(20261110)
spike <- capture(fit_data(matrix(one_spike(8192L), 8192L), 128, cs$span, cs$cell, rows = TRUE))$value
r[["zero-radius-1-8192-128"]] <- r_measured(spike$X, spike$y, spike$nd, cs)
write_json(r, file.path("docs", "figures", "result", "r-tied.json"))
