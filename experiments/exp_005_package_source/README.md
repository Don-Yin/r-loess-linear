# exp_005 package source

## do the kept changes still agree with R when combined?

![R and the package over N](../../docs/assets/exp_005-result.png)

at N=45,000, the package is 968× faster with 1,182× less workspace.

## does priority retention remove the slow tied cases?

![R and the package on tied inputs](../../docs/assets/exp_005-tied.png)

all 15 tied inputs beat R; the smallest speedup is 1.1×.

[how to run, inputs and outputs](docs/details.md)
