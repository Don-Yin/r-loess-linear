# experiments

| experiment | result | memory against R | time against R | source lines against&nbsp;R |
| --- | --- | --- | --- | --- |
| [exp_000 cache](exp_000_nov6_cache/README.md) | <a href="../docs/assets/exp_000-result.png"><img alt="R and cache" src="../docs/assets/exp_000-result.png" width="400"></a> | same | 123× faster | +74 / −27 |
| [exp_001 actual vertices](exp_001_actual_vertices/README.md) | <a href="../docs/assets/exp_001-result.png"><img alt="R and actual vertices" src="../docs/assets/exp_001-result.png" width="400"></a> | 1,301× less | 233× faster | +176 / −82 |
| [exp_002 baseline](exp_002_baseline_prototype/README.md) | <a href="../docs/assets/exp_002-result.png"><img alt="R and prototype" src="../docs/assets/exp_002-result.png" width="400"></a> | 504× less | 999× faster | +2,160 / −38 |
| [exp_003 reductions](exp_003_reductions/README.md) | <a href="../docs/assets/exp_003-result.png"><img alt="R and reductions" src="../docs/assets/exp_003-result.png" width="400"></a> | 504–1,182× less | 523–986× faster | +1,727–2,191 / −38–60 |
| [exp_004 worst case](exp_004_worst_case/README.md) | <a href="../docs/assets/exp_004-result.png"><img alt="R and prototype caps" src="../docs/assets/exp_004-result.png" width="400"></a> | 504× less<br>tied grid: 15× more | 978× faster<br>tied grid: 25× slower | +2,160 / −38 |
| [exp_005 package source](exp_005_package_source/README.md) | <a href="../docs/assets/exp_005-result.png"><img alt="R and package" src="../docs/assets/exp_005-result.png" width="400"></a> | 1,182× less<br>tied grid: 15× more | 968× faster<br>tied grid: 2.0× faster | +1,253 / −59 |
| [exp_006 sparse retention](exp_006_sparse_retention/README.md) | <a href="../docs/assets/exp_006-result.png"><img alt="R and sparse retention" src="../docs/assets/exp_006-result.png" width="400"></a> | 1,601× less<br>tied grid: 7.5× more | 925× faster<br>tied grid: 2.0× faster | +1,312 / −60 |
| [exp_007 shorter source](exp_007_shorter_source/README.md) | <a href="../docs/assets/exp_007-result.png"><img alt="R and shorter source" src="../docs/assets/exp_007-result.png" width="400"></a> | 1,182× less | 970× faster | +1,277 / −1,748 |

| experiment | result | memory against scikit-misc | time against scikit-misc | source lines against scikit-misc |
| --- | --- | --- | --- | --- |
| [exp_008 Python](exp_008_python_skmisc/README.md) | <a href="../docs/assets/exp_008-result.png"><img alt="Python builds" src="../docs/assets/exp_008-result.png" width="400"></a> | cache: same<br>actual: 1,301× less | cache: 130× faster<br>actual: 238× faster | cache: +57 / −20<br>actual: +161 / −75 |

figures use elapsed medians and requested workspace with orange zooms; see the [method](../docs/003-experiment-protocol.md).
