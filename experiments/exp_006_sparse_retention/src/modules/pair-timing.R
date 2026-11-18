# worker: Rscript <this file> <before dir> <after dir> <before probe dir> <after probe dir> <output csv> [profile path]
# The nine timing cases, before against after directly: user CPU of the plain builds, interleaved, each call
# repeated because the difference is below the timer's resolution; bytes from the probe builds.
args <- commandArgs(TRUE)
self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
harness <- normalizePath(file.path(dirname(gsub("~+~", " ", self, fixed = TRUE)), "..", "..", "..", "..", "shared", "harness"))
for (file in c("common.R", "speed.R", "memory.R")) source(file.path(harness, file))
start_profile(args[6])
labels <- c("before", "after")
plain <- lapply(setNames(args[1:2], labels), load_loess, so = "loessfactorpredict.so")
probed <- lapply(setNames(args[3:4], labels), load_loess, so = "loessfactorpredict.so")
step <- progress(length(timing_cases)); raw <- list()
rows <- lapply(seq_along(timing_cases), function(i) {
  case <- names(timing_cases)[i]; step(i, case); data <- timing_data(timing_cases[[i]])
  calls <- lapply(plain, function(build) function() build$predict.loess(data$fit, data$nd, se = TRUE))
  reference <- capture(predict(data$fit, data$nd, se = TRUE))
  identical_out <- all(vapply(c(plain, probed), function(build)
    same(reference, capture(build$predict.loess(data$fit, data$nd, se = TRUE))), NA))
  values <- lapply(probed, probe_values)
  s <- interleaved_seconds(calls, 9L, batch = 10L)
  raw[[i]] <<- timing_rounds(case, "public", s)
  data.frame(case, identical = identical_out, before_s = s[["before"]], after_s = s[["after"]],
    before_native_bytes = values$before$native_bytes, after_native_bytes = values$after$native_bytes,
    needed_vertices = values$after$needed_vertices, before_retained_vertices = values$before$retained_vertices,
    after_retained_vertices = values$after$retained_vertices, load1 = load1())
})
r <- do.call(rbind, rows); write.csv(r, args[5], row.names = FALSE); print(r, row.names = FALSE)
write.csv(do.call(rbind, raw), sub("[.]csv$", "-rounds.csv", args[5]), row.names = FALSE)
Rprof(NULL)
