# decisions

- the output stays bit for bit identical to R's: values, warnings and errors. no tolerance
- one function, `loesslin::predict_se()`, on a fit from R's own `loess()`. it replaces nothing in R; the aim is that R adopts the change
- the package source is `exp_003`: the kept changes of `exp_001`, plus zero-radius vertices retained first
- `exp_004` is a candidate and is not in the package
- package, experiments and harness are R only; the figures are drawn with Python
- every figure shows original R and the builds of that one experiment
- licence as R's (GPL 2 or 3); the AT&T notice stays on every loess source file

<img alt="the changes of exp_001 against R" src="assets/exp_001-result.png" width="520">

the eight changes of `exp_001`; one was dropped for being slower.
