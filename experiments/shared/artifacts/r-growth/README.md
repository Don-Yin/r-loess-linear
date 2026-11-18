# R growth reference

- purpose: R timings and exact predictions
- producer: exp_002_baseline_prototype; shared/harness/growth-worker.R
- inputs: shared/harness/common.R:toby_data; shared/harness/memory.R; OMP_NUM_THREADS=1; BLAS threads=1
- timing: five elapsed predict(se=TRUE) calls/N; median, min, max, sd; setup/gc untimed
- consumers: standard R figures
- regenerate: Rscript shared/harness/growth-worker.R --experiments=002,005 (existing artifact reused; never overwritten)
