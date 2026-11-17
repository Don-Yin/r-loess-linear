# decisions

- the output stays bit for bit identical to R's: values, warnings and errors. no tolerance
- one function, `loesslin::predict_se()`, on a fit from R's own `loess()`. it replaces nothing in R; the aim is that R adopts the change
- `exp_000` caches inverse-neighbor lookups; `exp_001` then stores coefficients for the actual tree vertices. both retain a quadratic worst case and the full influence matrix
- `exp_002` records and replays vertex fits; `exp_003` tests eight separate reductions; `exp_004` checks tied worst cases
- the package source is `exp_005`: the kept changes of `exp_003`, plus zero-radius vertices retained first. its current physical source-line difference is in [the experiment table](../experiments/README.md) and `exp_005`'s `lines-against-r.csv: variant=package, part=source`; notices count, the standalone build adapter does not
- `exp_006` retains only each vertex's neighborhood. it is a candidate and is not in the package
- the package and R harness stay in R, C and Fortran; `exp_008` separately ports the cache and actual-vertex changes to scikit-misc 0.5.3 in Python. figures are drawn with Python
- each R figure compares original R with the builds of that one experiment; the Python-port figure uses unpatched scikit-misc as its reference
- licence as R's (GPL 2 or 3); the AT&T notice stays on every loess source file

<img alt="the changes of exp_003 against R" src="assets/exp_003-result.png" width="520">

the eight changes of `exp_003`; one was dropped for being slower.

## 2026-11-17 public preparation

- modification notices use the dates recorded by the file histories: the cache, prototype and later sparse retention remain distinct changes. adding an attribution statement does not redate an algorithm
- complete GPL-2 and GPL-3 texts accompany the repository; [licences](licences.md) and [source provenance](source-provenance.md) separate R, AT&T, LINPACK and figure-logo terms
- line counts include physical notice lines and come from each experiment's `lines-against-r.csv`; Python-port counts use its pinned scikit-misc source and `lines-against-skmisc.csv`
- `exp_007` leads with `deletions_only`, which retains the common-case speed. `reduced` stays only as the documented size-versus-speed comparison
