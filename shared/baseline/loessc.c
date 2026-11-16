/*
 * Copyright (C) 1998--2025  The R Core Team
 *
 * The authors of this software are Cleveland, Grosse, and Shyu.
 * Copyright (c) 1989, 1992 by AT&T.
 * Permission to use, copy, modify, and distribute this software for any
 * purpose without fee is hereby granted, provided that this entire notice
 * is included in all copies of any software which is or includes a copy
 * or modification of this software and in all copies of the supporting
 * documentation for such software.
 * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTY.  IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
 * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
 * OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
 */

/* <UTF8> chars are handled as whole strings.
   They are passed from Fortran so had better be ASCII.
 */

/*
 *  Altered by B.D. Ripley to use F77_*, declare routines before use.
 *
 *  'protoize'd to ANSI C headers; indented: M.Maechler
 *
 *  Changes to the C/Fortran interface to support LTO in May 2019.
 *
 *  lowesd() : eliminate 'version' argument { also in ./loessf.f }
 */

#ifdef HAVE_CONFIG_H
// for FC_LEN_T
#include <config.h>
#endif

#include <string.h>
#include <stdio.h>
#include <math.h>
#include <limits.h>

#include <Rmath.h> // R_pow_di()
#include "modreg.h"
#include "variance-reduce.h"


/* Forward declarations */
static
void loess_workspace(int D, int N, double span, int degree,
		     int nonparametric, const int drop_square[],
		     int sum_drop_sqr, bool setLf);

static
void loess_prune(int *parameter, int *a,
		 double *xi, double *vert, double *vval);
static
void loess_grow (int *parameter, int *a,
		 double *xi, double *vert, double *vval);

/* These (and many more) are in ./loessf.f : */
void F77_NAME(lowesa)(double*, int*, int*, int*, int*, double*, double*);
void F77_NAME(lowesb)(double*, double*, double*, double*, int*, int*, double*);
void F77_NAME(lowesc)(int*, double*, double*, double*, double*, double*);
void F77_NAME(lowesd)(int* iv, int* liv, int* lv, double *v,
		      int* d, int* n, double* f,
		      int* ideg, int* nf, int* nvmax, int* setlf);
void F77_NAME(lowese)(int*, double*, int*, double*, double*);
void F77_NAME(lowesf)(double*, double*, double*, int*, double*,
		      int*, double*, double*, int*, double*);
void F77_NAME(lowesl)(int*, double*, int*, double*, double*, int*, int*);
void F77_NAME(ehg169)(int*, int*, int*, int*, int*, int*,
		      double*, int*, double*, int*, int*, int*);
void F77_NAME(ehg196)(int*, int*, double*, double*);
/* exported (for loessf.f) : */
void F77_SUB(loesswarn)(int *i);
#ifdef FC_LEN_T
# include <stddef.h>
void F77_SUB(ehg183a)(char *s, int *nc,int *i,int *n,int *inc, FC_LEN_T c1);
void F77_SUB(ehg184a)(char *s, int *nc, double *x, int *n, int *inc, FC_LEN_T c1);
#else
void F77_SUB(ehg183a)(char *s, int *nc,int *i,int *n,int *inc);
void F77_SUB(ehg184a)(char *s, int *nc, double *x, int *n, int *inc);
#endif


#undef min
#undef max

#define	min(x,y)  ((x) < (y) ? (x) : (y))
#define	max(x,y)  ((x) > (y) ? (x) : (y))
#define	GAUSSIAN	1
#define SYMMETRIC	0

// Global variables :
static int	*iv = NULL, liv, lv, tau;
static double	*v = NULL;

/* these are set in an earlier call to loess_workspace or loess_grow */
static void loess_free(void)
{
    R_Free(v);
    R_Free(iv);
}

void
loess_raw(double *y, double *x, double *weights, double *robust, int *d,
	  int *n, double *span, int *degree, int *nonparametric,
	  int *drop_square, int *sum_drop_sqr, double *cell,
	  char **surf_stat, double *surface, int *parameter,
	  int *a, double *xi, double *vert, double *vval, double *diagonal,
	  double *trL, double *one_delta, double *two_delta, int *setLf)
{
    int i0 = 0, one = 1, two = 2, nsing, i, k;
    double *hat_matrix, *LL, d0=0.0;

    *trL = 0;

    loess_workspace(*d, *n, *span, *degree, *nonparametric, drop_square, *sum_drop_sqr,  (bool)*setLf);
    v[1] = *cell;/* = v(2) in Fortran (!) */

    /* NB:  surf_stat  =  (surface / statistics);
     *                               statistics = "none" for all robustness iterations
     */
    if(!strcmp(*surf_stat, "interpolate/none")) { // default for loess.smooth() and robustness iter.
	F77_CALL(lowesb)(x, y, robust, &d0, &i0, iv, v);
	F77_CALL(lowese)(iv, v, n, x, surface);
	loess_prune(parameter, a, xi, vert, vval);
    }
    else if (!strcmp(*surf_stat, "direct/none")) {
	F77_CALL(lowesf)(x, y, robust, iv, v, n, x, &d0, &i0, surface);
    }
    else if (!strcmp(*surf_stat, "interpolate/1.approx")) { // default (trace.hat is "exact")
	F77_CALL(lowesb)(x, y, weights, diagonal, &one, iv, v);
	F77_CALL(lowese)(iv, v, n, x, surface);
	nsing = iv[29];
	for(i = 0; i < (*n); i++) *trL = *trL + diagonal[i];
	F77_CALL(lowesa)(trL, n, d, &tau, &nsing, one_delta, two_delta);
	loess_prune(parameter, a, xi, vert, vval);
    }
    else if (!strcmp(*surf_stat, "interpolate/2.approx")) { // default for trace.hat = "approximate"
	//                     vvvvvvv (had 'robust' in R <= 3.2.x)
	F77_CALL(lowesb)(x, y, weights, &d0, &i0, iv, v);
	F77_CALL(lowese)(iv, v, n, x, surface);
	nsing = iv[29];
	F77_CALL(ehg196)(&tau, d, span, trL);
	F77_CALL(lowesa)(trL, n, d, &tau, &nsing, one_delta, two_delta);
	loess_prune(parameter, a, xi, vert, vval);
    }
    else if (!strcmp(*surf_stat, "direct/approximate")) {
	F77_CALL(lowesf)(x, y, weights, iv, v, n, x, diagonal, &one, surface);
	nsing = iv[29];
	for(i = 0; i < (*n); i++) *trL = *trL + diagonal[i];
	F77_CALL(lowesa)(trL, n, d, &tau, &nsing, one_delta, two_delta);
    }
    else if (!strcmp(*surf_stat, "interpolate/exact")) {
        int cache = 0, inv = 0;
	hat_matrix = (double *) R_alloc((*n)*(*n), sizeof(double));
	LL = (double *) R_alloc((*n)*(*n), sizeof(double));
	F77_CALL(lowesb)(x, y, weights, diagonal, &one, iv, v);
	F77_CALL(lowesl)(iv, v, n, x, hat_matrix, &cache, &inv);
	F77_CALL(lowesc)(n, hat_matrix, LL, trL, one_delta, two_delta);
	F77_CALL(lowese)(iv, v, n, x, surface);
	loess_prune(parameter, a, xi, vert, vval);
    }
    else if (!strcmp(*surf_stat, "direct/exact")) {
	hat_matrix = (double *) R_alloc((*n)*(*n), sizeof(double));
	LL = (double *) R_alloc((*n)*(*n), sizeof(double));
	F77_CALL(lowesf)(x, y, weights, iv, v, n, x, hat_matrix, &two, surface);
	F77_CALL(lowesc)(n, hat_matrix, LL, trL, one_delta, two_delta);
	k = (*n) + 1;
	for(i = 0; i < (*n); i++)
	    diagonal[i] = hat_matrix[i * k];
    }
    loess_free();
}

void
loess_dfit(double *y, double *x, double *x_evaluate, double *weights,
	   double *span, int *degree, int *nonparametric,
	   int *drop_square, int *sum_drop_sqr,
	   int *d, int *n, int *m, double *fit)
{
    int i0 = 0;
    double d0 = 0.0;

    loess_workspace(*d, *n, *span, *degree, *nonparametric, drop_square, *sum_drop_sqr, FALSE);
    F77_CALL(lowesf)(x, y, weights, iv, v, m, x_evaluate, &d0, &i0, fit);
    loess_free();
}

void
loess_dfitse(double *y, double *x, double *x_evaluate, double *weights,
	     double *robust, int *family, double *span, int *degree,
	     int *nonparametric, int *drop_square,
	     int *sum_drop_sqr,
	     int *d, int *n, int *m, double *fit, double *L)
{
    loess_workspace(*d, *n, *span, *degree, *nonparametric, drop_square, *sum_drop_sqr, FALSE);

    int i2 = 2;
    if(*family == GAUSSIAN)
	F77_CALL(lowesf)(x, y, weights, iv, v, m, x_evaluate,  L,  &i2, fit);
    else if(*family == SYMMETRIC)
    {
	int i0 = 0; double d0 = 0.0;
	F77_CALL(lowesf)(x, y, weights, iv, v, m, x_evaluate,  L,  &i2, fit);
	F77_CALL(lowesf)(x, y, robust,  iv, v, m, x_evaluate, &d0, &i0, fit);
    }
    loess_free();
}

void
loess_ifit(int *parameter, int *a, double *xi, double *vert,
	   double *vval, int *m, double *x_evaluate, double *fit)
{
    loess_grow(parameter, a, xi, vert, vval);
    F77_CALL(lowese)(iv, v, m, x_evaluate, fit);
    loess_free();
}

// Called from R's predLoess()  when 'se = TRUE' (and the default surface == "interpolate")
#ifndef LOESS_COEFFICIENT_BLOCK
#define LOESS_COEFFICIENT_BLOCK 1
#endif
#if LOESS_COEFFICIENT_BLOCK < 1
#error LOESS_COEFFICIENT_BLOCK must be positive
#endif
#ifndef LOESS_RETENTION_BYTES
#define LOESS_RETENTION_BYTES 67108864
#endif
#if LOESS_RETENTION_BYTES < 0
#error LOESS_RETENTION_BYTES must be nonnegative
#endif
void F77_NAME(lowesv)(double*,int*,double*);
void F77_NAME(lowesfp)(double*,double*,int*,double*,int*,int*,double*,int*,int*,int*,double*);
void F77_NAME(lowesfb)(int*,double*,double*,double*,int*,int*,double*,int*,int*,int*,double*,int*,int*,double*,int*);
void F77_NAME(lowesfz)(int*,double*,double*,double*,int*,int*,int*,double*,int*);
void F77_NAME(lowesgp)(int*,double*,int*,double*,int*,double*,int*);
void F77_NAME(lowesgwarn)(int*,double*,double*,double*);
void F77_NAME(lowesfpeval)(int*,int*,int*,double*,double*,double*);
void F77_NAME(lowesfnp)(int*,double*,int*,double*,int*,double*,int*,double*,int*);
void F77_NAME(lowesfne)(int*,double*,int*,double*,int*,double*,int*,double*,int*,double*,double*);
void F77_NAME(lowesfdep)(int*,double*,int*,double*,double*,int*);
static double factor_observed[20],factor_geometry_bytes,retention_observed[4],factor_exceptional[3];
void loess_exception_probe(double *out) { memcpy(out,factor_exceptional,sizeof(factor_exceptional)); }
void loess_retention_probe(double *out) { memcpy(out,retention_observed,sizeof(retention_observed)); }
void loess_geometry_probe(double *out) { out[0]=factor_geometry_bytes;out[1]=1.; }
void loess_probe(double *out) { memcpy(out,factor_observed,sizeof(factor_observed)); }
void loess_block_probe(double *out) {
    out[0]=LOESS_COEFFICIENT_BLOCK;
    out[1]=ceil(factor_observed[0]/LOESS_COEFFICIENT_BLOCK);
}

/* Dedicated callbacks for the geometry-only copy of actual ehg128 reads.
 * No warning API is intercepted; ordinary interpolation still owns diagnostics. */
static int *dep_which,*dep_warn,dep_nv,dep_m,dep_query;
void F77_SUB(fdepset)(int *point) {
    if(*point<1||*point>dep_m)error("dependency point exceeds prediction count");
    dep_query=*point-2;
}
void F77_SUB(fdepbegin)(void) {
    if(++dep_query<0||dep_query>=dep_m)error("dependency plan query index exceeds prediction count");
}
void F77_SUB(fdepwarn)(void) { dep_warn[dep_query]=1; }
double F77_SUB(fdepread)(double *value,int *vertex) {
    if(*vertex<1||*vertex>dep_nv)error("dependency plan vertex index exceeds tree size");
    dep_which[*vertex-1]=1;
    return *value;
}

static void
loess_factor_core(double *y,double *x,double *z,double *weights,
    double *span,int *degree,int *nonparametric,int *drop_square,
    int *sum_drop_sqr,double *cell,int *d,int *n,int *m,double *fit,
    double *variance,double *full_L,int *cache)
{
    if(*d<1||*d>4)error("scalar-record prediction prototype implements D=1 through D=4");
    loess_workspace(*d,*n,*span,*degree,*nonparametric,drop_square,*sum_drop_sqr,FALSE);
    v[1]=*cell;
    F77_CALL(lowesv)(x,iv,v);
    int nv=iv[5],nvmax=iv[13],planned=*d==1,vc=iv[3],edges=*d==2;
    int k=*degree==0?1:iv[28]-(*degree>1?*sum_drop_sqr:0);
    if(k>iv[18]) {
        loess_free();error("scalar-record prototype requires at least k neighborhood rows");
    }
    int rs=3*k*k+(*d+5)*k+1;
    double ncoef=(*d+1.)*nvmax;
    if(max(max(5.* *d,edges?20.:0.),LOESS_COEFFICIENT_BLOCK)* *m>=INT_MAX||
       ncoef*LOESS_COEFFICIENT_BLOCK>=INT_MAX) {
        loess_free();error("scalar-record prototype prediction plan exceeds integer range");
    }
    int *ids=(int*)R_alloc((size_t)vc* *m,sizeof(int));
    double *basis=(double*)R_alloc((size_t)5* *d* *m,sizeof(double));
    int edge_placeholder=0;double edge_basis_placeholder=0.;
    int *edgeids=edges?(int*)R_alloc((size_t)8* *m,sizeof(int)):&edge_placeholder;
    double *edgebasis=edges?(double*)R_alloc((size_t)20* *m,sizeof(double)):&edge_basis_placeholder;
    int *iwarn=(int*)R_alloc((size_t)*m,sizeof(int));
    int *which=(int*)R_alloc((size_t)nv,sizeof(int));
    double *coef=(double*)R_alloc((size_t)ncoef*LOESS_COEFFICIENT_BLOCK,sizeof(double));
    memset(which,0,(size_t)nv*sizeof(int));
    memset(iwarn,0,(size_t)*m*sizeof(int));
    memset(coef,0,(size_t)ncoef*LOESS_COEFFICIENT_BLOCK*sizeof(double));
    if(planned)F77_CALL(lowesgp)(iv,v,m,z,ids,basis,iwarn);
    else F77_CALL(lowesfnp)(iv,v,m,z,ids,basis,edgeids,edgebasis,iwarn);
    for(int i=0;i<vc* *m;++i)which[ids[i]-1]=1;
    if(edges)for(int p=0;p<*m;++p)if(!iwarn[p])
        for(int e=0;e<8;++e)which[edgeids[8*p+e]-1]=1;
    if(!planned) {
        dep_which=which;dep_warn=iwarn;dep_nv=nv;dep_m=*m;dep_query=-1;
        F77_CALL(lowesfdep)(iv,v,m,z,coef,iwarn);
    }
    int needed=0;
    for(int l=0;l<nv;++l)if(which[l])which[l]=++needed;
    double nr=(double)rs*needed,ni=(double)k*needed;
    if(nr>=INT_MAX||ni>=INT_MAX) {
        loess_free();error("scalar-record prototype workspace exceeds Fortran integer range");
    }
    /* Retain original producer coefficients under a fixed byte cap.
       Size by actual needed vertices, not the tree's nvmax capacity. */
    double vertex_bytes=sizeof(double)*(*d+1.)* *n;
    int keep_count=min(needed,(int)floor(LOESS_RETENTION_BYTES/vertex_bytes));
    size_t keep_values=(size_t)(*d+1)* *n*keep_count;
    int *keepof=(int*)R_alloc((size_t)nv,sizeof(int));
    double keep_placeholder=0.;
    double *kept=keep_values?(double*)R_alloc(keep_values,sizeof(double)):&keep_placeholder;
    memset(keepof,0,(size_t)nv*sizeof(int));
    memset(kept,0,keep_values*sizeof(double));
    for(int l=0,slot=0;l<nv;++l)if(which[l]&&slot<keep_count)keepof[l]=++slot;
    double *rec=(double*)R_alloc((size_t)nr,sizeof(double));
    int *first=(int*)R_alloc((size_t)ni,sizeof(int));
    int *exceptional=(int*)R_alloc((size_t)nv,sizeof(int));
    memset(exceptional,0,(size_t)nv*sizeof(int));
    double *block=(double*)R_alloc((size_t)*m*LOESS_COEFFICIENT_BLOCK,sizeof(double));
    double *terms=(double*)R_alloc((size_t)*m,sizeof(double));
    loess_sum *sums=(loess_sum*)R_alloc((size_t)*m,sizeof(loess_sum));
    memset(sums,0,(size_t)*m*sizeof(loess_sum));
    F77_CALL(lowesfp)(x,weights,iv,v,&k,&rs,rec,first,which,keepof,kept);
    /* Nonfinite records need the original full-neighborhood arithmetic.
       Retained producer results already have it; replay only the remainder. */
    int nexceptional=0,nzero=0;
    for(int l=0;l<nv;++l)if(which[l]) {
        const double *record=rec+(size_t)rs*(which[l]-1);
        int nonfinite=!(record[rs-1]>0.);
        if(record[rs-1]==0.)++nzero;
        for(int i=0;i<rs;++i)if(!R_FINITE(record[i]))nonfinite=1;
        if(nonfinite&&!keepof[l]) { exceptional[l]=1;++nexceptional; }
    }
    int batches=(*n+LOESS_COEFFICIENT_BLOCK-1)/LOESS_COEFFICIENT_BLOCK;
    factor_exceptional[0]=nzero;
    factor_exceptional[1]=nexceptional;
    factor_exceptional[2]=(double)nexceptional*batches;
    double diag_calls=0;
    if(planned)for(int j=0;j<*n;++j)for(int i=0;i<*m;++i)if(iwarn[i]) {
        F77_CALL(lowesgwarn)(iv,v,z+i,coef);
        ++diag_calls;
    }
    for(int j=0;j<*n;j+=LOESS_COEFFICIENT_BLOCK) {
        int j0=j+1,nb=min(LOESS_COEFFICIENT_BLOCK,*n-j);
        F77_CALL(lowesfb)(iv,v,x,weights,&k,&rs,rec,first,&j0,&nb,coef,which,keepof,kept,exceptional);
        if(nexceptional)F77_CALL(lowesfz)(iv,v,x,weights,&k,&j0,&nb,coef,exceptional);
        for(int b=0;b<nb;++b) {
            double *column=coef+(size_t)b*(size_t)ncoef;
            double *result=block+(size_t)b* *m;
            if(planned)F77_CALL(lowesfpeval)(m,&nvmax,ids,basis,column,result);
            else F77_CALL(lowesfne)(iv,v,m,z,ids,basis,edgeids,edgebasis,iwarn,column,result);
        }
        loess_variance_add(sums,block,weights+j,*m,nb,terms);
        if(full_L)memcpy(full_L+(size_t)j* *m,block,(size_t)*m*nb*sizeof(double));
    }
    if(!planned)for(int i=0;i<*m;++i)if(iwarn[i])diag_calls+=*n;
    if(variance)for(int i=0;i<*m;++i)variance[i]=(double)sums[i];
    double base=sizeof(int)*(double)liv+sizeof(double)*(double)lv;
    double plan_ints=(vc+1.+(edges?8.:0.))* *m;
    double plan_doubles=(5.* *d+(edges?20.:0.))* *m;
    factor_geometry_bytes=sizeof(int)*plan_ints+sizeof(double)*plan_doubles;
    double extra=sizeof(int)*(ni+plan_ints+2.*nv)+
        sizeof(double)*(nr+ncoef*LOESS_COEFFICIENT_BLOCK+plan_doubles+
                       (LOESS_COEFFICIENT_BLOCK+1.)* *m)+
        sizeof(loess_sum)*(double)*m+sizeof(int)*(double)nv+
        sizeof(double)*(double)keep_values;
    double keep_stats[4]={LOESS_RETENTION_BYTES,keep_count,
        sizeof(double)*(double)keep_values,sizeof(int)*(double)nv};
    memcpy(retention_observed,keep_stats,sizeof(keep_stats));
    double values[20]={*n,*m,*d,iv[18],nv,k,rs,nr,ni,
        1+(nexceptional?batches:0),nv+(double)nexceptional*batches,
        diag_calls,base,extra,base+extra,sizeof(loess_sum),liv,lv,
        full_L?8.* *n* *m:0.,needed};
    memcpy(factor_observed,values,sizeof(values));
    (void)y; /* Only the already-fitted value path depends on the response. */
    (void)cache;(void)fit;
    loess_free();
}

void
loess_ise(double *y,double *x,double *z,double *weights,double *span,
    int *degree,int *nonparametric,int *drop_square,int *sum_drop_sqr,
    double *cell,int *d,int *n,int *m,double *fit,double *variance,int *cache)
{
    loess_factor_core(y,x,z,weights,span,degree,nonparametric,drop_square,
        sum_drop_sqr,cell,d,n,m,fit,variance,NULL,cache);
}

/* Verification-only full output belongs to the caller, never the SE kernel. */
void
loess_factor_L(double *y,double *x,double *z,double *weights,double *span,
    int *degree,int *nonparametric,int *drop_square,int *sum_drop_sqr,
    double *cell,int *d,int *n,int *m,double *fit,double *L,int *cache)
{
    loess_factor_core(y,x,z,weights,span,degree,nonparametric,drop_square,
        sum_drop_sqr,cell,d,n,m,fit,NULL,L,cache);
}

// Set global variables  tau, lv, liv , and allocate global arrays  v[1..lv],  iv[1..liv]
void
loess_workspace(int D, int N, double span, int degree,
		int nonparametric, const int drop_square[],
		int sum_drop_sqr, bool setLf)
{
    int nvmax = max(200, N),
	nf = min(N, (int) floor(N * span + 1e-5));
    if(nf <= 0) error(_("span is too small"));
    // NB: D := ncol(x) is  <=  3
    int tau0 = (degree > 1) ? ((D + 2) * (D + 1)) / 2 : (D + 1);
    tau = tau0 - sum_drop_sqr;
    double dlv  = 50 + (3 * D + 3) * (double)nvmax + N + (tau0 + 2.) * nf;
    double dliv = 50 + (R_pow_di(2., D) + 4.) * nvmax + 2. * N;
    if(setLf) {
        dlv  += (D + 1.) * nf * (double)nvmax;
	dliv +=            nf * (double)nvmax;
    }

    if (dlv < INT_MAX && dliv < INT_MAX) { // set the global vars
	lv  = (int) dlv;
	liv = (int) dliv;
    } else {
	error(_("workspace required (%.0f) is too large%s."), max(dlv, dliv),
	      setLf ? _(" probably because of setting 'se = TRUE'") : "");
    }

    iv = R_Calloc(liv, int);
    v  = R_Calloc(lv, double);

    // Do the initialization in Fortran.
    int isetLf = setLf;  // This is INTEGER in the Fortran routine
    F77_CALL(lowesd)(iv, &liv, &lv, v, &D, &N, &span,
		     &degree, &nf, &nvmax, &isetLf);
    iv[32] = nonparametric;
    for(int i = 0; i < D; i++)
	iv[i + 40] = drop_square[i];
}

static void
loess_prune(int *parameter, int *a, double *xi, double *vert,
	    double *vval)
{
    int d, vc, a1, v1, xi1, vv1, nc, nv, nvmax, i, k;

    d = iv[1];
    vc = iv[3] - 1;
    nc = iv[4];
    nv = iv[5];
    a1 = iv[6] - 1;
    v1 = iv[10] - 1;
    xi1 = iv[11] - 1;
    vv1 = iv[12] - 1;
    nvmax = iv[13];

    for(i = 0; i < 5; i++)
	parameter[i] = iv[i + 1];
    parameter[5] = iv[21] - 1;
    parameter[6] = iv[14] - 1;

    for(i = 0; i < d; i++) {
	k = nvmax * i;
	vert[i] = v[v1 + k];
	vert[i + d] = v[v1 + vc + k];
    }
    for(i = 0; i < nc; i++) {
	xi[i] = v[xi1 + i];
	a[i] = iv[a1 + i];
    }
    k = (d + 1) * nv;
    for(i = 0; i < k; i++)
	vval[i] = v[vv1 + i];
}

static void
loess_grow(int *parameter, int *a, double *xi,
	   double *vert, double *vval)
{
    int d, vc, nc, nv, a1, v1, xi1, vv1, i, k;

    d = parameter[0];
    vc = parameter[2];
    nc = parameter[3];
    nv = parameter[4];
    liv = parameter[5];
    lv = parameter[6];
    iv = R_Calloc(liv, int);
    v = R_Calloc(lv, double);

    iv[1] = d;
    iv[2] = parameter[1];
    iv[3] = vc;
    iv[5] = iv[13] = nv;
    iv[4] = iv[16] = nc;
    iv[6] = 50;
    iv[7] = iv[6] + nc;
    iv[8] = iv[7] + vc * nc;
    iv[9] = iv[8] + nc;
    iv[10] = 50;
    iv[12] = iv[10] + nv * d;
    iv[11] = iv[12] + (d + 1) * nv;
    iv[27] = 173;

    v1 = iv[10] - 1;
    xi1 = iv[11] - 1;
    a1 = iv[6] - 1;
    vv1 = iv[12] - 1;

    for(i = 0; i < d; i++) {
	k = nv * i;
	v[v1 + k] = vert[i];
	v[v1 + vc - 1 + k] = vert[i + d];
    }
    for(i = 0; i < nc; i++) {
	v[xi1 + i] = xi[i];
	iv[a1 + i] = a[i];
    }
    k = (d + 1) * nv;
    for(i = 0; i < k; i++)
	v[vv1 + i] = vval[i];

    F77_CALL(ehg169)(&d, &vc, &nc, &nc, &nv, &nv, v+v1, iv+a1,
		    v+xi1, iv+iv[7]-1, iv+iv[8]-1, iv+iv[9]-1);
}


/* begin ehg's FORTRAN-callable C-codes */
#define MSG(_m_)	msg = _(_m_) ; break ;

void F77_SUB(loesswarn)(int *i)
{
    char *msg, msg2[50];

switch(*i){
 case 100:MSG("wrong version number in lowesd.   Probably typo in caller.")
 case 101:MSG("d>dMAX in ehg131.  Need to recompile with increased dimensions.")
 case 102:MSG("liv too small.    (Discovered by lowesd)")
 case 103:MSG("lv too small.     (Discovered by lowesd)")
 case 104:MSG("span too small.   fewer data values than degrees of freedom.")
 case 105:MSG("k>d2MAX in ehg136.  Need to recompile with increased dimensions.")
 case 106:MSG("lwork too small")
 case 107:MSG("invalid value for kernel")
 case 108:MSG("invalid value for ideg")
 case 109:MSG("lowstt only applies when kernel=1.")
 case 110:MSG("not enough extra workspace for robustness calculation")
 case 120:MSG("zero-width neighborhood. make span bigger")
 case 121:MSG("all data on boundary of neighborhood. make span bigger")
 case 122:MSG("extrapolation not allowed with blending")
 case 123:MSG("ihat=1 (diag L) in l2fit only makes sense if z=x (eval=data).")
 case 171:MSG("lowesd must be called first.")
 case 172:MSG("lowesf must not come between lowesb and lowese, lowesr, or lowesl.")
 case 173:MSG("lowesb must come before lowese, lowesr, or lowesl.")
 case 174:MSG("lowesb need not be called twice.")
 case 175:MSG("need setLf=.true. for lowesl.")
 case 180:MSG("nv>nvmax in cpvert.")
 case 181:MSG("nt>20 in eval.")
 case 182:MSG("svddc failed in l2fit.")
 case 183:MSG("didn't find edge in vleaf.")
 case 184:MSG("zero-width cell found in vleaf.")
 case 185:MSG("trouble descending to leaf in vleaf.")
 case 186:MSG("insufficient workspace for lowesf.")
 case 187:MSG("insufficient stack space")
 case 188:MSG("lv too small for computing explicit L")
 case 191:MSG("computed trace L was negative; something is wrong!")
 case 192:MSG("computed delta was negative; something is wrong!")
 case 193:MSG("workspace in loread appears to be corrupted")
 case 194:MSG("trouble in l2fit/l2tr")
 case 195:MSG("only constant, linear, or quadratic local models allowed")
 case 196:MSG("degree must be at least 1 for vertex influence matrix")
 case 999:MSG("not yet implemented")
 default: {
     snprintf(msg2, 50, "Assert failed; error code %d\n",*i);
     msg = msg2;
 }
}
warning("%s", msg);
}
#undef MSG

#ifdef FC_LEN_T
void F77_SUB(ehg183a)(char *s, int *nc,int *i,int *n,int *inc, FC_LEN_T c1)
#else
void F77_SUB(ehg183a)(char *s, int *nc,int *i,int *n,int *inc)
#endif
{
    int nnc = *nc;
    char mess[4000], num[20];
    strncpy(mess, s, nnc);
    mess[nnc] = '\0';
    for (int j = 0; j < *n; j++) {
	snprintf(num, 20, " %d", i[j * *inc]);
	strcat(mess, num);
    }
    strcat(mess,"\n");
    warning("%s", mess);
}

#ifdef FC_LEN_T
void F77_SUB(ehg184a)(char *s, int *nc, double *x, int *n, int *inc, FC_LEN_T c1)
#else
void F77_SUB(ehg184a)(char *s, int *nc, double *x, int *n, int *inc)
#endif
{
    int nnc = *nc;
    char mess[4000], num[30];
    strncpy(mess, s, nnc);
    mess[nnc] = '\0';
    for (int j = 0; j < *n; j++) {
	snprintf(num, 30, " %.5g", x[j * *inc]);
	strcat(mess, num);
    }
    strcat(mess,"\n");
    warning("%s", mess);
}
