# R loess sources

| item | value | source |
| --- | --- | --- |
| R-devel revision | 90840 | `verification.csv: revision, url` |
| upstream files | `loess.R`, `loessc.c`, `loessf.f`, `modreg.h`, `statsErr.h` | `verification.csv: file, identical` |
| registration adapter | standalone, not an upstream numerical routine | `register.c` |
| registered routines; standard-error arguments | 5; 15 | the same source |

- the source files are byte-identical to the fixed upstream revision.
- the R wrapper comes from `stats/R/`; the native files come from `stats/src/`.
- builds stay in experiment-private directories.
- source files are never patched in place.
- [Source provenance](../../docs/source-provenance.md) records authors and changes.
- [COPYRIGHTS](../../inst/COPYRIGHTS) retains the applicable notices.

```bash
Rscript shared/harness/lines.R
```
