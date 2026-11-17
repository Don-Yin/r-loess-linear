# original R loess sources

`loess.R`, `loessc.c`, `loessf.f`, `modreg.h` and `statsErr.h` are unchanged R-devel sources at Subversion revision 90840, the revision named in [tdhock/atime#135](https://github.com/tdhock/atime/issues/135).

The cache patch was reversed from `shared/reference-nov6/`; all five files were then downloaded from R's Subversion server at that revision and compared byte for byte. `verification.csv` records each source URL and the comparison result. The URL form `https://svn.r-project.org/R/!svn/bc/90840/trunk/src/library/stats/src/loessc.c` selects that fixed revision; `loess.R` is under `stats/R/` instead of `stats/src/`.

`register.c` is a minimal standalone-library build adapter, not an upstream source file. It registers only the five loess routines, with the original 15-argument `loess_ise` entry. The adapter is included in `shared/harness/variant.R:line_count`; `Rscript shared/harness/lines.R` prints its contribution separately from the source contribution.

Builds are private to each experiment's `.intermediates/`. The original sources are never patched in place. [Source provenance](../../docs/source-provenance.md) links the public cache patch, the R main-program and LINPACK sources, and the subsequent changes; [COPYRIGHTS](../../inst/COPYRIGHTS) records the applicable notices.
