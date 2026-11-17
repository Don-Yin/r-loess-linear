# Exercise complete fit results and the silent exceptional-vertex replay.
verify_fit <- function(root, profile = TRUE, name = NULL) {
  work <- variant_work(root, name)
  replay <- check_at_cap(root, 0, profile = profile, name = name)
  fit_path <- result_path(root, "json", "fit-cases.json", name)
  replay_path <- result_path(root, "json", "replay-cases.json", name)
  worker(root, file.path(root, "src", "modules", "fit-cases.R"),
    c(file.path(work, "src"), fit_path, replay$dir, replay_path),
    "fit-cases", profile, name)
  fit <- jsonlite::read_json(fit_path); tied <- jsonlite::read_json(replay_path)
  data.frame(suite = c("fit-objects", "cap-0", "exceptional-replay"),
    identical = c(fit$identical, replay$identical, tied$identical), cases = c(fit$cases, replay$cases, tied$cases))
}
