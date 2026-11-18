extern int openblas_get_num_threads(void);

/* Read the loaded BLAS runtime; this helper changes no library setting. */

void loess_measure_blas_threads(int *out)
{
    *out = openblas_get_num_threads();
}
