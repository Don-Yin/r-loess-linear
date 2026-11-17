# Derived from src/library/stats/R/loess.R in R.
# Copyright (C) 1998-2023 The R Core Team
# Copyright (C) 2026 Don Yin
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
# https://www.R-project.org/Licenses/ for the full license text.
#
# The authors of this software are Cleveland, Grosse, and Shyu.
# Copyright (c) 1989, 1992 by AT&T.
# Permission to use, copy, modify, and distribute this software for any
# purpose without fee is hereby granted, provided that this entire notice
# is included in all copies of any software which is or includes a copy
# or modification of this software and in all copies of the supporting
# documentation for such software.
# THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTY. IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
# REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
# OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.

# Modified by Don Yin on 2026-11-11: extract prediction from R-devel
# r90840 loess.R and use ordered native variance blocks for interpolation.

predict_se <- function(object, newdata = NULL)
{
    if (!inherits(object, "loess"))
        stop("first argument must be a \"loess\" object")

    op <- object$pars
    res <- predLoess(object$y, object$x,
                     newx = if (is.null(newdata)) object$x
                            else if (is.data.frame(newdata))
                                as.matrix(model.frame(delete.response(terms(object)),
                                                      newdata, na.action = na.pass))
                            else as.matrix(newdata),
                     object$s, object$weights, object$robust,
                     op$span, op$degree, op$parametric, op$drop.square,
                     op$surface, op$cell, op$family, object$kd, object$divisor)
    if (!is.null(out.attrs <- attr(newdata, "out.attrs"))) {
        res$fit <- array(res$fit, out.attrs$dim, out.attrs$dimnames)
        res$se.fit <- array(res$se.fit, out.attrs$dim, out.attrs$dimnames)
    }
    res$df <- object$one.delta^2/object$two.delta
    res
}

predLoess <- function(y, x, newx, s, weights, robust, span, degree,
                      parametric, drop.square, surface, cell, family, kd, divisor)
{
    D <- NCOL(x); N <- NROW(x); M <- NROW(newx)
    x <- as.matrix(x); newx <- as.matrix(newx)
    if (any(divisor != 1)) {
        newx <- newx/rep(divisor, rep_len(M, D))
        x <- x/rep(divisor, rep_len(N, D))
    }
    sum.drop.sqr <- sum(drop.square)
    nonparametric <- sum(!parametric)
    order.parametric <- order(parametric)
    x <- x[, order.parametric, drop = FALSE]
    x.evaluate <- newx[, order.parametric, drop = FALSE]
    order.drop.sqr <- (2L - drop.square)[order.parametric]
    storage.mode(x) <- "double"
    storage.mode(y) <- "double"
    N <- nrow(x)
    if (length(weights) < N) weights <- rep(1, N)
    if (length(robust) < N) robust <- rep(1, N)
    if (surface == "direct") {
        nas <- rowSums(is.na(newx)) > 0
        fit <- rep_len(NA_real_, length(nas))
        se.fit <- fit
        x.evaluate <- x.evaluate[!nas, , drop = FALSE]
        M <- nrow(x.evaluate)
        z <- .C(C_loess_dfitse,
                y, x, as.double(x.evaluate),
                as.double(weights * robust), as.double(robust),
                as.integer(family == "gaussian"), as.double(span),
                as.integer(degree), as.integer(nonparametric),
                as.integer(order.drop.sqr), as.integer(sum.drop.sqr),
                as.integer(D), as.integer(N), as.integer(M),
                fit = double(M), L = double(N * M))[c("fit", "L")]
        fit[!nas] <- z$fit
        ses <- rowSums(matrix(z$L^2, M, N)/rep(weights, rep_len(M, N)))
        se.fit[!nas] <- s * sqrt(ses)
    } else {
        ranges <- apply(x, 2L, range)
        inside <- rowSums((x.evaluate <= rep(ranges[2L, ], rep_len(M, D))) &
                          (x.evaluate >= rep(ranges[1L, ], rep_len(M, D)))) == D
        inside[is.na(inside)] <- FALSE
        M1 <- sum(inside)
        fit <- se.fit <- rep_len(NA_real_, M)
        if (any(inside)) {
            fit[inside] <- .C(C_loess_ifit,
                              as.integer(kd$parameter), as.integer(kd$a),
                              as.double(kd$xi), as.double(kd$vert),
                              as.double(kd$vval), as.integer(M1),
                              as.double(x.evaluate[inside, ]), fit = double(M1))$fit
            variance <- .C(C_loess_ise,
                            y, x, as.double(x.evaluate[inside, ]),
                            as.double(weights), as.double(span),
                            as.integer(degree), as.integer(nonparametric),
                            as.integer(order.drop.sqr), as.integer(sum.drop.sqr),
                            as.double(span * cell), as.integer(D),
                            as.integer(N), as.integer(M1), double(M1),
                            variance = double(M1), 1L)$variance
            se.fit[inside] <- s * sqrt(variance)
        }
    }
    rn <- rownames(newx)
    if (!is.null(rn)) names(fit) <- names(se.fit) <- rn
    list(fit = fit, se.fit = drop(se.fit), residual.scale = s)
}
