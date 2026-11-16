/*
 * Copyright (C) 2026 Don Yin
 *
 * The authors of this software are Cleveland, Grosse, and Shyu.
 * Copyright (c) 1989, 1992 by AT&T.
 * Permission to use, copy, modify, and distribute this software for any
 * purpose without fee is hereby granted, provided that this entire notice
 * is included in all copies of any software which is or includes a copy
 * or modification of this software and in all copies of the supporting
 * documentation for such software.
 * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTY. IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
 * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
 * OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
 */
#include "modreg.h"
#include <R_ext/Rdynload.h>
#ifdef LOESS_TESTING
void loess_factor_L(double*,double*,double*,double*,double*,int*,int*,int*,int*,double*,int*,int*,int*,double*,double*,int*);
void loess_probe(double*);
void loess_block_probe(double*);
void loess_geometry_probe(double*);
void loess_retention_probe(double*);
void loess_exception_probe(double*);
#endif
#define C_DEF(name,n) {#name,(DL_FUNC)&name,n}
static const R_CMethodDef ent[]={    C_DEF(loess_raw, 24),
    C_DEF(loess_dfit, 13),
    C_DEF(loess_dfitse, 16),
    C_DEF(loess_ifit, 8),
    C_DEF(loess_ise, 16),
#ifdef LOESS_TESTING
    C_DEF(loess_factor_L,16),C_DEF(loess_probe,1),C_DEF(loess_block_probe,1),C_DEF(loess_geometry_probe,1),C_DEF(loess_retention_probe,1),C_DEF(loess_exception_probe,1),
#endif
    {NULL,NULL,0}};
void R_init_loesslin(DllInfo *dll) {
R_registerRoutines(dll,ent,NULL,NULL,NULL);R_useDynamicSymbols(dll,FALSE);R_forceSymbols(dll,TRUE);
}
