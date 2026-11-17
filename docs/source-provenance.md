# source provenance

## original sources

The five original loess files in [`shared/reference-r/`](../shared/reference-r/README.md) are unchanged R-devel Subversion revision **90840**. [`verification.csv`](../shared/reference-r/verification.csv) records their fixed-revision URLs and byte comparisons. This is the revision named in [tdhock/atime#135](https://github.com/tdhock/atime/issues/135), not an assertion that the prototype was copied from the test host's R release.

| repository component | upstream source at R revision 90840 | attribution and terms |
|---|---|---|
| `loess.R` and `R/predict-se.R` | [`src/library/stats/R/loess.R`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/R/loess.R) | R Core Team; GPL version 2 or later |
| `loessc.c`, `loessf.f`, `captured-127.f` | [`loessc.c`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/loessc.c), [`loessf.f`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/loessf.f) | R Core Team; William S. Cleveland, Eric Grosse, Ming-Jen Shyu; complete AT&T notice retained |
| `modreg.h`, `statsErr.h` | [`modreg.h`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/modreg.h), [`statsErr.h`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/statsErr.h) | R Core Team and R Foundation where stated; GPL version 2 or later; `statsErr.h` has no separate upstream notice |
| both `variance-reduce.h` files | [`src/main/array.c`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/main/array.c), `do_colsum` rows branch; [`src/main/arithmetic.c`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/main/arithmetic.c), `R_pow(x, 2)` | R Core Team, R Foundation, Robert Gentleman and Ross Ihaka; GPL version 2 or later |
| `dqrdcx.f`, `dqrslx.f`, `captured-qr.f` | [`src/appl/dqrdc.f`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/appl/dqrdc.f), [`src/appl/dqrsl.f`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/appl/dqrsl.f) | G. W. Stewart, LINPACK `dqrdc` and `dqrsl`, original version dated 08/14/78; [R's copyright-status caveat](https://svn.r-project.org/R/!svn/bc/90840/trunk/doc/COPYRIGHTS) retained |
| `register.c` adapters | the five loess entries in [`stats/src/init.c`](https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/init.c) | standalone registration adapters, not copies of an AT&T numerical routine |

The original AT&T notice is reproduced in [`inst/COPYRIGHTS`](../inst/COPYRIGHTS), the package help and every loess implementation file. LINPACK adaptations are not labelled globally public domain: R says their status is unclear and reports the claim only for the USA.

## changes retained in this repository

The [public cache patch](https://github.com/user-attachments/files/34593952/loess-predict-cache-arg.diff.txt), linked from [Toby Dylan Hocking's comment](https://github.com/tdhock/atime/issues/135#issuecomment-6748730446), is Don Yin's cache-argument and inverse-neighbor modification. Its SHA-256 is `5d46a3e78d481fcf32a145a2690115508342c47ab31c27b44b48d2ff2387adc2`. `shared/reference-nov6/` retains that change on R revision 90840; `exp_000` builds it, and `exp_001` separates tree construction from smoothing so the influence arrays use the actual vertex count.

`shared/baseline/` adds compact local-fit records, extracted `fhg127`, captured LINPACK scalars, ordered coefficient replay and R's exact-order variance reduction. `exp_002` and `exp_004` build that prototype. The independent `exp_003` patches remove or adjust one part at a time; `exp_005` combines the retained changes into the package source, while `exp_006` stores only neighborhood rows in retained coefficient slots. `exp_007` applies the documented deletion and reduction patches to a private package copy. The cache change is marked in the files as modified by Don Yin on 2026-11-06. The prototype, captured LINPACK routines, variance reduction and package adaptations are dated 2026-11-11, as recorded in their file histories; the sparse-retention change is dated 2026-11-13. The newer actual-vertex, shorter-source and Python-port changes retain their 2026-11-17 notices. Adding a source or attribution statement does not redate the underlying algorithm. Patch files retain the applicable file notices in their resulting sources and complete-file copies.

`exp_008` downloads pinned scikit-misc 0.5.3 from PyPI rather than redistributing its full tree. Its README and `src/modules/sources.py` name the archive URL and checksum. `cache.patch` ports the R cache change and `actual-vertices.patch` ports `exp_001`, retaining scikit-misc's original AT&T notices and recording Don Yin's modifications. The source and port comparison tables check the relationship with the unchanged R Fortran core.

The shared timing input follows [the public atime issue](https://github.com/tdhock/atime/issues/135); using atime to produce measurements does not copy its implementation into this package. The [licence summary](licences.md) separately credits the R and Python logos used in repository figures and links their applicable terms.
