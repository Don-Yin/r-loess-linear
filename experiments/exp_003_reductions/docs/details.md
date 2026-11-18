# reduction details

## run

```bash
Rscript experiments/exp_003_reductions/run.R
Rscript shared/harness/growth-worker.R --experiments=003
```

- prerequisites are listed in the [protocol](../../../docs/003-experiment-protocol.md#run).
- `--no-profile` disables profiling.
- `source_defaults` uses no flags; other variants use the measured block width and cap.

## inputs

| input | path |
| --- | --- |
| prototype; cache reference | `shared/baseline/`; `shared/reference-nov6/` |
| independent patches; verdicts | `patches/<name>.patch`; `src/variants.csv` |
| measured block width; cap | 32 columns; 64 MiB (`shared/harness/variant.R: flags_at, MEASURED_CAP`) |

## standard results

| quantity | value | source file and column |
| --- | --- | --- |
| observations | 45,000 | `.results/tables/growth.csv: N` |
| time; workspace ranges | 23.2–43.7 ms; 17.1–40.2 MB | the same file: `median_seconds, requested_bytes` |
| speed; workspace ratios to R | 523–986× faster; 504–1,182× less | local and shared R `growth.csv` |
| checks, every variant | 275/275 identical | `.results/tables/reductions.csv: identical, cases` |

## independent changes

| variant | source lines against R | ordinary bytes | extra checks | verdict |
| --- | ---: | ---: | ---: | --- |
| `block_buffer_by_vertex_count` | +2,160 / −38 | 15,701,128 | — | keep |
| `source_defaults` | +2,160 / −38 | 38,732,424 | — | keep |
| `probes_out_of_production` | +2,178 / −38 | 38,732,424 | 419/419 | keep |
| `trimmed_qr` | +1,727 / −38 | 38,732,424 | 75/75 | keep |
| `single_plan_path` | +2,074 / −38 | 38,732,424 | 6/6 | drop |
| `no_instrumented_ehg128` | +1,763 / −38 | 38,732,424 | 19/19 | keep |
| `single_vertex_fit` | +2,006 / −60 | 38,732,424 | 491/491 | keep |
| `zero_radius_retained_first` | +2,191 / −38 | 38,732,424 | 565/565 | keep |

- sources are `lines-against-r.csv: added, removed` and `reductions.csv: native_bytes_n45000, extra_identical, extra_cases, verdict`.

## costs and limits

| case | value | source file and column |
| --- | --- | --- |
| dropped one-predictor cost | 1.8–4.3× kept-build time | `.results/tables/<variant>-timing.csv: variant_s` |
| dropped/reference ratios | 0.29, 0.36, 0.34 | `.results/tables/reductions.csv: ratio_d1-*` |
| kept/reference ratio ranges | 0.14–0.16; 0.19–0.20; 0.08–0.09 | the same columns, standard case order |
| flagged-point vertices, before/after | 10 / 130 | `.results/tables/no_instrumented_ehg128-flagged-timing.csv: baseline_needed, variant_needed` |
| flagged-point bytes, before/after | 2,367,608 / 8,275,448 | the same file: `baseline_bytes, variant_bytes` |
| registered entries, normal/test build | 5 / 11 | `.results/json/probes_out_of_production-test-api.json: production_entries, testing_entries` |
| exceptional replay cases | 10 of 24 | `.results/json/single_vertex_fit-replay-cases.json: cases_with_exceptional_replay, cases` |
| priority-retention small cap | 65,536 B | `.results/tables/zero_radius_retained_first-retention-cap-65536.csv: cap_bytes` |
| replay counts when the vertex fits | 128 → 0 at N=4,096 | the same file: `baseline_replay_vertex_fits, variant_replay_vertex_fits` |
| replay counts when it does not fit | 256 → 256 at N=8,192 | the same columns |

- cache-reference timing can change state on the two-predictor input.
- normalised ratios do not establish a build-speed difference on that input.
- ordinary inputs differ from the standard figure's input.
- the production build has no allocation probe; its test build supplies byte counts.

## outputs

| output | path |
| --- | --- |
| tables; summaries | `.results/tables/`; `.results/json/` |
| logs; profiles | `.results/logs/`; `.results/profile/` |
