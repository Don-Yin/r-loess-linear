# worst-case details

## run

```bash
Rscript experiments/exp_004_worst_case/run.R
Rscript shared/harness/growth-worker.R --experiments=004
```

- prerequisites are listed in the [protocol](../../../docs/003-experiment-protocol.md#run).
- `--no-profile` disables profiling.
- inputs are `shared/baseline/`, `shared/reference-nov6/` and `shared/harness/tied.R`.
- no algorithm patch is applied.

## checks and standard input

| quantity | value | source file and column |
| --- | --- | --- |
| standard observations | 45,000 | `.results/tables/growth.csv: N` |
| elapsed time; workspace | 23.4 ms; 40.2 MB | the same file: `build=cap-67108864, median_seconds, requested_bytes` |
| ratios to R | 978× faster; 504× less workspace | local and shared R `growth.csv` |
| source lines against R | +2,160 / −38 | `.results/tables/lines-against-r.csv: part=source, added, removed` |
| retention caps | 64 MiB; 1 MiB; 64 KiB; zero | `.results/tables/worst-cap-*.csv: cap_bytes` |
| shared checks, each cap | 275/275 identical | `.results/json/summary.json: build_checks` |
| stress; depth; tied; control checks | 21/21; 4/4; 15/15; 6/6 | the same file: `worst_case, depth, tied_default_cap` |

## retention and depth

| input | result | source file and column |
| --- | --- | --- |
| over-cap, default / no retention | 0.54–0.77 / 0.55–0.91 of cache time | `.results/tables/worst-cap-67108864.csv`, `worst-cap-0.csv: ratio` |
| largest needed / retained set | 4,065 / 409 vertices | the same tables: `needed_vertices, retained_vertices` |
| over-cap workspace at N=4,096 | 85–102 MB; cache 219–253 MB | the same tables: `baseline_native_bytes, nov6_native_bytes` |
| over-cap workspace at N=1,024 | 36–51 MB; cache 14–16 MB | the same columns |
| unretained zero-radius vertex | 1.6× cache time at N=4,096; 3.1–3.2× at N=8,192 | `worst-cap-65536.csv`, `worst-cap-0.csv: ratio` |
| zero-radius default cap | 0.22–0.28 of cache time | `worst-cap-67108864.csv: suite=zero-radius, ratio` |
| zero-radius largest input | 0.0064 s; 7.4 MB; R 0.536 s and 269 MB | the same file: `baseline_s, baseline_native_bytes`; `r-tied.json: zero-radius-1-8192-128` |
| deepest tree | depth 20 at N=524,289 | `.results/tables/depth.csv: max_depth, n` |

- the depth test builds a tree and evaluates once; it does not run a full prediction.
- the `nt>20 in eval.` warning is preserved.
- A zero-radius vertex has coincident observations throughout its neighbourhood.

## tied inputs

| case | zero-radius vertices not retained | fits redone | time/cache |
| --- | ---: | ---: | ---: |
| repeated-grid-3-8192 | 44 | 11,264 | 15.1 |
| repeated-grid-4-4096 | 53 | 6,784 | 7.1 |
| repeated-grid-4-8192 | 95 | 24,320 | 15.1 |
| grid-cloud-2-8192 | 186 | 47,616 | 34.0 |
| grid-cloud-3-8192 | 49 | 12,544 | 38.3 |

- source is `.results/tables/default-cap-findings.csv: unretained_zero_radius_vertices, replay_vertex_fits, ratio`.

| limit or comparison | value | source file and column |
| --- | --- | --- |
| public prediction errors | 8 tied inputs | `.results/tables/default-cap-findings.csv: public_error` |
| other tied/cache ratios | 0.47–0.75 | the same file: `ratio`, no unretained zero-radius vertices, excluding the last grid |
| last grid/cache ratio | 1.30 | the same file: `id=grid-cloud-4-8192, ratio` |
| worst tied input against R | 31.1 s / 1.26 s; 25× slower | the same file: `baseline_s`; `docs/figures/result/r-tied.json: seconds` |

- native standard-error routines are compared directly when public prediction stops.
- R tied times come from a separate run, so their ratios are rough.

## outputs

| output | path |
| --- | --- |
| tables; summary | `.results/tables/`; `.results/json/summary.json` |
| logs; profiles | `.results/logs/`; `.results/profile/` |
