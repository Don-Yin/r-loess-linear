#include "modreg.h"
#include <R_ext/Rdynload.h>
void loess_factor_L(double*,double*,double*,double*,double*,int*,int*,int*,int*,double*,int*,int*,int*,double*,double*,int*);
void loess_probe(double*);
void loess_block_probe(double*);
void loess_geometry_probe(double*);
void loess_retention_probe(double*);
void loess_exception_probe(double*);
#define C_DEF(name,n) {#name,(DL_FUNC)&name,n}
static const R_CMethodDef ent[]={    C_DEF(loess_raw, 24),
    C_DEF(loess_dfit, 13),
    C_DEF(loess_dfitse, 16),
    C_DEF(loess_ifit, 8),
    C_DEF(loess_ise, 16),
C_DEF(loess_factor_L,16),C_DEF(loess_probe,1),C_DEF(loess_block_probe,1),C_DEF(loess_geometry_probe,1),C_DEF(loess_retention_probe,1),C_DEF(loess_exception_probe,1),{NULL,NULL,0}};
void R_init_loessfactorpredict(DllInfo *dll) {
R_registerRoutines(dll,ent,NULL,NULL,NULL);R_useDynamicSymbols(dll,FALSE);R_forceSymbols(dll,TRUE);
}
