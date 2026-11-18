# package-source details

## run

```bash
Rscript experiments/exp_005_package_source/run.R
Rscript shared/harness/growth-worker.R --experiments=005
```

- prerequisites are listed in the [protocol](../../../docs/003-experiment-protocol.md#run).
- `--no-profile` disables profiling.
- both builds use source defaults without flags.
- tied measurements use separate probe builds.

## inputs

| input | path |
| --- | --- |
| prototype; cache reference | `shared/baseline/`; `shared/reference-nov6/` |
| package changes | `variant.patch` |
| same changes without priority retention | `patches/stack.patch` |
| tied cases | `shared/harness/tied.R` |

## results

| quantity | value | source file and column |
| --- | --- | --- |
| standard observations | 45,000 | `.results/tables/growth.csv: N` |
| elapsed time; workspace | 23.6 ms; 17.1 MB | the same file: `median_seconds, requested_bytes` |
| ratios to R | 968× faster; 1,182× less workspace | local and shared R `growth.csv` |
| shared checks, both builds and retention modes | 275/275 identical | `.results/json/summary.json: checks, priority_on_stack` |
| tied comparisons; controls | 15/15; 6/6 identical | the same file: `priority_on_stack.metrics` |
| package source lines against R | +1,253 / −59 | `.results/tables/lines-against-r.csv: variant=package, part=source, added, removed` |
| stack source lines against R | +1,223 / −60 | the same file: `variant=stack, part=source, added, removed` |
| ordinary normalised / direct time ratios | 0.99–1.10 / 0.97–1.07 | `.results/tables/shared-timing-comparison.csv: priority_to_stack_ratio, priority_to_stack_seconds` |
| tied workspace excess over R | 6–20× on 9 inputs | `.results/tables/tied-comparison.csv: priority_baseline_native_bytes`; `r-tied.json: bytes` |

## priority retention

| case | fits redone before → after | CPU seconds before → after | after/cache |
| --- | ---: | ---: | ---: |
| repeated-grid-3-8192 | 11,264 → 0 | 2.37 → 0.10 | 0.66 |
| repeated-grid-4-4096 | 6,784 → 0 | 1.36 → 0.15 | 0.77 |
| repeated-grid-4-8192 | 24,320 → 0 | 5.24 → 0.26 | 0.77 |
| grid-cloud-2-8192 | 47,616 → 0 | 23.32 → 0.39 | 0.57 |
| grid-cloud-3-8192 | 12,544 → 0 | 29.57 → 0.64 | 0.83 |

- source is `.results/tables/tied-comparison.csv: stack/priority_replay_vertex_fits, stack/priority_baseline_s, priority_ratio`.
- native byte requests are equal in each before/after pair.

## limits

| quantity | value | source file and column |
| --- | --- | --- |
| public tied errors | 8 inputs | `.results/tables/tied-comparison.csv: public_error` |
| last grid time, package / cache | 1.40 / 1.15 s; ratio 1.23 | the same file: `priority_baseline_s, priority_nov6_s, priority_ratio` |
| last grid vertices, needed / retained | 5,699 / 204 | the same file: `needed_vertices`; `tied-priority-cap-67108864.csv: retained_vertices` |
| last grid workspace, package / cache | 117 / 276 MB | the same file: `priority_baseline_native_bytes, priority_nov6_native_bytes` |

- public prediction errors persist after the native replay work is removed.
- the last grid has no zero-radius vertex.
- the last grid's remaining cost is unresolved.
- R tied times come from a separate run, so their ratios are rough.
- sparse retention remains a separate [candidate](../../exp_006_sparse_retention/README.md).

## outputs

| output | path |
| --- | --- |
| tables; summaries | `.results/tables/`; `.results/json/` |
| logs; profiles | `.results/logs/`; `.results/profile/` |
