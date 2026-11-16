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
/* Exact-order loess standard-error reduction.
 * R source: array.c do_colsum rows branch, arithmetic.c R_pow(x, 2).
 * The host uses long double for rowSums; validate this type against R when
 * building on another target. Do not replace it with a Rust f64 assumption.
 */
#ifndef LOESS_VARIANCE_REDUCE_H
#define LOESS_VARIANCE_REDUCE_H
#include <stddef.h>

typedef long double loess_sum;

static void loess_variance_add(loess_sum *sums, const double *block,
                               const double *weights, size_t rows,
                               size_t columns, double *terms)
{
    for (size_t j = 0; j < columns; ++j) {
        const double *column = block + rows * j;
        for (size_t i = 0; i < rows; ++i) {
            const double square = column[i] * column[i];
            terms[i] = square / weights[j];
        }
        /* Keep R's materialized-double operands and accumulation loop. */
        loess_sum *ra = sums;
        const double *rx = terms;
        for (size_t i = 0; i < rows; ++i) *ra++ += *rx++;
    }
}
#endif
