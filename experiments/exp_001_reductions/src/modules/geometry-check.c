/* Expose geometry-only entry points for the flagged-point checks. */
#include <R_ext/RS.h>
#include <R_ext/Rdynload.h>

extern void F77_NAME(lowesd)(int*,int*,int*,double*,int*,int*,double*,int*,int*,int*,int*);
extern void F77_NAME(lowesv)(double*,int*,double*);
extern void F77_NAME(lowesfnp)(int*,double*,int*,double*,int*,double*,int*,double*,int*);

void R_init_geometrycheck(DllInfo *dll)
{
    static const R_FortranMethodDef entries[] = {
        {"lowesd", (DL_FUNC)&F77_NAME(lowesd), 11},
        {"lowesv", (DL_FUNC)&F77_NAME(lowesv), 3},
        {"lowesfnp", (DL_FUNC)&F77_NAME(lowesfnp), 9},
        {NULL, NULL, 0}
    };
    R_registerRoutines(dll, NULL, NULL, entries, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
