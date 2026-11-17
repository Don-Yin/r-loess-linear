# experiment protocol

one experiment answers one question. a change is a patch against `shared/baseline/`, tested alone.

```sh
Rscript experiments/exp_NNN_<slug>/run.R
```

this applies the patch to a copy, builds it, runs the 275 checks and the timing, and writes `.results/` (not in git). it exits nonzero when a case is not identical. it needs `patch`, `diff` and the R package `jsonlite`.

## rules

1. every patch starts from the baseline, never from another patch
2. the result stays bit for bit identical: no tolerance, no changed default
3. the order of floating point operations and of BLAS calls stays
4. a change that is slower, or cannot stay identical, is a result: record it and stop
5. an experiment changes only its own folder; shared code lives in `shared/harness/`

## where things are

| folder | holds |
|---|---|
| `shared/reference-r/` | unchanged R-devel r90840 sources: base for source line counts |
| `shared/reference-nov6/` | R-devel r90840 plus the public cache patch: timing and exactness reference |
| `shared/baseline/` | the linear-memory prototype, patched only in private build copies |
| `shared/harness/` | build, checks, `speed.R` and `memory.R`, the same for every experiment |
| `experiments/exp_NNN_<slug>/` | the patch, `run.R` and a README with the figures and every number |

[Source provenance](source-provenance.md) fixes the R revision, original file URLs, public cache patch and subsequent changes. [Licences](licences.md) distinguishes the source-code terms from the R logo's terms.
