# source provenance

## fixed R source

| item | record | source |
| --- | --- | --- |
| R-devel revision | 90840 | [`verification.csv`](../shared/reference-r/verification.csv): `revision, url, identical` |
| context | revision named by the public timing input | [atime issue](https://github.com/tdhock/atime/issues/135) |

| repository component | upstream source | attribution and terms |
| --- | --- | --- |
| `loess.R`, `R/predict-se.R` | [stats `loess.R`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/R/loess.R) | R Core Team; GPL version 2 or later |
| `loessc.c`, `loessf.f`, `captured-127.f` | [C](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/loessc.c); [Fortran](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/loessf.f) | R Core Team; Cleveland, Grosse and Shyu; full AT&T notice |
| `modreg.h`, `statsErr.h` | [header](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/modreg.h); [error header](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/statsErr.h) | R Core Team and R Foundation where stated; GPL version 2 or later; no separate `statsErr.h` notice |
| `variance-reduce.h` | [`do_colsum` rows branch](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/main/array.c); [`R_pow`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/main/arithmetic.c) | R Core Team, R Foundation, Robert Gentleman and Ross Ihaka; GPL version 2 or later |
| QR adaptations | [`dqrdc`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/appl/dqrdc.f); [`dqrsl`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/appl/dqrsl.f) | G. W. Stewart; LINPACK; [R's copyright caveat](https://svn.r-project.org/R/!svn/bc/90840/trunk/doc/COPYRIGHTS) |
| `register.c` | [stats entry declarations](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/init.c) | standalone registration adapter |

- the fixed revision is distinct from the installed test host's R release.
- retain the AT&T notice in loess source copies and supporting documentation.
- LINPACK adaptations are not labelled globally public domain.
- [COPYRIGHTS](../inst/COPYRIGHTS) retains the component notices.

## retained changes

| component | change | source |
| --- | --- | --- |
| cache reference | Don Yin's cache argument and inverse-neighbour lookup | [public patch](https://github.com/user-attachments/files/34593952/loess-predict-cache-arg.diff.txt); [attribution](https://github.com/tdhock/atime/issues/135#issuecomment-6748730446) |
| actual-vertex storage | separate geometry from smoothing; use actual coefficient capacity | `experiments/exp_001_actual_vertices/variant.patch` |
| prototype | local-fit records, extracted fits, captured QR scalars and ordered replay | `shared/baseline/` |
| package | retained independent reductions and priority retention | `experiments/exp_005_package_source/variant.patch` |
| sparse candidate | neighbourhood-only retained coefficients | `experiments/exp_006_sparse_retention/variant.patch` |
| shorter-source candidates | independent deletions and reductions | `experiments/exp_007_shorter_source/patches/`; `variant.patch` |
| Python port | pinned scikit-misc archive and adapted allocation/error interfaces | `experiments/exp_008_python_skmisc/docs/details.md` |

- source files and resulting patches retain their copyright and modification notices.
- the Python distribution retains its BSD and AT&T texts.
- using atime for measurements does not incorporate its implementation into the package.
- figure-logo terms are separate in [licences](licences.md).
