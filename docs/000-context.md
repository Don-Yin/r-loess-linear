# context

R's `predict.loess(se = TRUE)` reserves a workspace for `nvmax = max(200, N)` k-d tree vertices, so its memory grows with N squared and N stops near 46,300 (span 0.5). loesslin keeps the same local fits and the same arithmetic, stores less, and recomputes what it did not store. the output is bit for bit identical to R's.

<img alt="memory requested over N for R and the prototype" src="assets/exp_000-memory.png" width="520">

## limits

- checked on macOS arm64 with R 4.5.2 only
- on tied grids it requests more memory than R: [results](004-results.md#against-original-r)
- for some medium sized fits it requests up to 28 MB more than R
- not built inside R's stats package
