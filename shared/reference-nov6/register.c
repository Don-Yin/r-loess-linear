#include "modreg.h"
#include <R_ext/Rdynload.h>

#define C_DEF(name,n) {#name,(DL_FUNC)&name,n}
static const R_CMethodDef ent[] = {    C_DEF(loess_raw, 24),
    C_DEF(loess_dfit, 13),
    C_DEF(loess_dfitse, 16),
    C_DEF(loess_ifit, 8),
    C_DEF(loess_ise, 16),
{NULL,NULL,0}};
void R_init_loesssent(DllInfo *dll) {
R_registerRoutines(dll,ent,NULL,NULL,NULL);
R_useDynamicSymbols(dll,FALSE);R_forceSymbols(dll,TRUE);
}
