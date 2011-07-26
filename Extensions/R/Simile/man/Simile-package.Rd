\name{Simile-package}
\alias{Simile-package}
\alias{Simile}
\docType{package}
\title{
  Interface to executable Simile models
}
\description{
This package loads, parameterizes, executes and interrogates executable
models saved by Simile.
}
\details{
\tabular{ll}{
Package: \tab Simile\cr
Type: \tab Package\cr
Version: \tab 1.0\cr
Date: \tab 2011-05-30\cr
License: \tab Unrestricted\cr
LazyLoad: \tab yes\cr
}
The package loads some Simile libraries into R's tcltk extension, so you
need Simile installed to use it. Initialize the package by calling
use.simile.at() to tell it where to find Simile in the file system. Tell
it where to find the saved executable model with load.model() which
returns a handle to the loaded model. This can be used to interrogate
static model info via list.objects() and get.model.property(), and to
create executable instances with create.model(), which returns their handles.

An executable instance can be parameterized either by loading a Simile
parameter metafile with consult.parameter.metafile(), or directly from R
arrays with create.param.array() and set.model.parameter(). The
functions set.model.step(), reset.model() and execute.model() control
execution. Use get.value.array() to get the values from any model
component as an R array. 
}
\author{
  Simulistics Ltd
}
\references{
Simile modelling environment: simulistics.com
}
%% ~~ Optionally other standard keywords, one per line, from file KEYWORDS in ~~
%% ~~ the R documentation directory ~~
\keyword{ model }
\seealso{
%% ~~ Optional links to other man pages, e.g. ~~
%% ~~ \code{\link[<pkg>:<pkg>-package]{<pkg>}} ~~
}
\examples{
%% ~~ simple examples of the most important functions ~~
}
