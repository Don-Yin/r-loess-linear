/*
 *  R : A Computer Language for Statistical Data Analysis
 *  Copyright (C) 1998-2026 The R Core Team
 *  Copyright (C) 2002-2025 The R Foundation
 *  Copyright (C) 1995-1997 Robert Gentleman and Ross Ihaka
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, a copy is available at
 *  https://www.R-project.org/Licenses/
 */

/* Copyright (C) 2026 Don Yin for the block-reduction interface.
 * Modified by Don Yin on 2026-11-11: adapt R-devel revision 90840
 * src/main/array.c do_colsum rows and src/main/arithmetic.c R_pow(x, 2)
 * to ordered loess variance blocks. The R operations retain their order.
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
