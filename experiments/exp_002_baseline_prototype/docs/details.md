# prototype details

## run

```bash
Rscript experiments/exp_002_baseline_prototype/run.R
Rscript shared/harness/growth-worker.R --experiments=002
```

- prerequisites are listed in the [protocol](../../../docs/003-experiment-protocol.md#run).
- `--no-profile` disables profiling.

## inputs

| input | path |
| --- | --- |
| prototype; cache reference | `shared/baseline/`; `shared/reference-nov6/` |
| memory sweep; R timings | `src/modules/memory-sweep.R`; `src/modules/r-timing.R` |

## results

| quantity | value | source file and column |
| --- | --- | --- |
| standard observations | 45,000 | `.results/tables/growth.csv: N` |
| elapsed time; workspace | 22.9 ms; 40.2 MB | the same file: `median_seconds, requested_bytes` |
| ratios to R | 999× faster; 504× less workspace | shared R and local `growth.csv: median_seconds, requested_bytes` |
| shared checks | 275/275 identical | `.results/tables/checks.csv: identical` |
| source lines against R | +2,160 / −38 | `.results/tables/lines-against-r.csv: part=source, added, removed` |
| ordinary CPU/cache time | 0.08–0.89 | `.results/tables/timing.csv: ratio` |
| ordinary large-case workspace | 38,732,424 B | the same file: `case=d1-n45000-m80-cell0.2, native_bytes` |
| large-case workspace/cache ratio | 0.0019 | the same file: `native_bytes / nov6_native_bytes` |
| small-case workspace/cache ratios | 0.06–1.9 | the same file: predictor counts above one, `native_bytes / nov6_native_bytes` |
| memory sweep, small endpoint | N=500; 479,184 B; R 2,554,600 B | `.results/tables/memory.csv: n, native_bytes, r_workspace_bytes` |
| memory sweep, large endpoint | N=200,000; 178,433,184 B | the same file: `n, native_bytes` |
| first invalid R workspace | N=46,337 | the same file: `n, r_runs` |
| largest checked R memory-sweep prediction | N=20,000 | the same file: `n, identical_to_r` |

## limits

- the ordinary timing input differs from the standard figure's input.
- the small four-predictor full-tree case requests more workspace than the cache reference.
- R's workspace length eventually exceeds its integer limit.
- the public tied-input error and platform limits are in [results](../../../docs/004-results.md#limits).

## compare installed methods

```r
for (file in c("common.R", "speed.R", "memory.R")) source(file.path("shared", "harness", file))
nov6 <- load_loess("experiments/exp_002_baseline_prototype/.intermediates/reference-nov6", "loesssent.so")
data <- toby_data(20000)
calls <- list(
  R = function() predict(data$fit, data$nd, se = TRUE),
  nov6 = function() nov6$predict.loess(data$fit, data$nd, se = TRUE, cache = TRUE),
  loesslin = function() loesslin::predict_se(data$fit, data$nd))
sapply(lapply(calls, function(call) call()), same, calls$R())
interleaved_seconds(calls, rounds = 3L)
c(R = reference_bytes(1, 20000, 80, 0.5, 2, 0)[["native"]],
  nov6 = reference_bytes(1, 20000, 80, 0.5, 2, data$fit$kd$parameter[["nv"]])[["native"]])
```

- install the package with `R CMD INSTALL .` before this comparison.
- the comparison requires the experiment's built cache reference.

## outputs

| output | path |
| --- | --- |
| tables; summary | `.results/tables/`; `.results/json/summary.json` |
| logs; profiles | `.results/logs/`; `.results/profile/` |
