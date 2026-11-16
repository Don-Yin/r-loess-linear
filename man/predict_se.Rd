\name{predict_se}
\alias{predict_se}
\title{Loess Predictions with Standard Errors}
\description{
Compute predictions and pointwise standard errors from an existing
\code{\link[stats]{loess}} fit, with the same result as
\code{\link[stats]{predict.loess}(object, newdata, se = TRUE)}.
}
\usage{
predict_se(object, newdata = NULL)
}
\arguments{
  \item{object}{An object returned by \code{\link[stats]{loess}}.}
  \item{newdata}{An optional data frame of predictor values. If \code{NULL},
  use the original predictor values. A matrix or numeric vector is also
  accepted, as by R's loess prediction method.}
}
\details{
The interpolation surface stores compact local fit records and reconstructs
coefficient blocks in the original arithmetic order, rather than reserving
the quadratic standard-error workspace used by R. Retained coefficients
are limited to 64 MiB. The fit itself is computed by \code{stats::loess};
this package does not replace \code{loess} or register a prediction method.
The direct surface retains R's standard calculation and its workspace.

Data-frame prediction uses \code{\link[stats]{na.pass}}, the default of
R's loess prediction method. Predictions outside the data range are
\code{NA} for the interpolation surface. The return value, including names,
array dimensions, and missing values, matches R's prediction method.
The implementation has been checked on macOS arm64 with R 4.5.2;
other platforms have not yet been verified for bit-for-bit agreement.
}
\value{
A list with the same components as \code{predict(object, newdata, se = TRUE)}:
\item{fit}{Predicted values.}
\item{se.fit}{Estimated standard errors of the predictions.}
\item{residual.scale}{The residual scale estimate of the fit.}
\item{df}{Estimated degrees of freedom for the standard-error estimate.}
}
\seealso{\code{\link[stats]{loess}}, \code{\link[stats]{predict.loess}}}
\examples{
x <- seq(-2, 2, length.out = 100)
data <- data.frame(x = x, y = sin(x) + cos(7 * x)/10)
fit <- stats::loess(y ~ x, data = data)
newdata <- data.frame(x = c(-1, 0, 1))
result <- predict_se(fit, newdata)
stopifnot(identical(result, stats::predict(fit, newdata, se = TRUE)))
}
\section{Copyright}{
The authors of this software are Cleveland, Grosse, and Shyu.
Copyright (c) 1989, 1992 by AT&T.
Permission to use, copy, modify, and distribute this software for any
purpose without fee is hereby granted, provided that this entire notice
is included in all copies of any software which is or includes a copy
or modification of this software and in all copies of the supporting
documentation for such software.
THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
WARRANTY. IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
}
\keyword{models}
