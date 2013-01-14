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
Version: \tab 1.2\cr
Date: \tab 2012-10-11\cr
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
execution. get.model.time() returns the time at which execution
finished. Use get.value.array() to get the values from any model
component as an R array, or get.value.list() to get them as an R list.

This version works with Simile versions 5.94 on.
}
\author{
  Simulistics Ltd
}
\references{
Simile modelling environment: http://simulistics.com
}
%% ~~ Optionally other standard keywords, one per line, from file KEYWORDS in ~~
%% ~~ the R documentation directory ~~
\keyword{ model }
\examples{
%% ~~ simple examples of the most important functions ~~
\donttest{
% requires Simile installation plus saved executable model so cannot be
% auto tested
require("Simile")
path.to.installation <- tcl("tk_chooseDirectory", "-title",
"Folder where Simile is installed:")
use.simile.at(path.to.installation)

exec.extn <- as.character(tcl("info","sharedlibextension"))
path.to.spiro <- tcl("tk_getOpenFile",
                     "-title", "Compiled binary for Spiro example:",
                     "-initialfile", paste("spiro",exec.extn,sep=""))
mHandle <- load.model(path.to.spiro)
objs <- list.objects(mHandle)

for (obj in objs) {
  print(c(obj, get.model.property(mHandle, obj, "Class")))
}

iHandle <- create.model(mHandle)
# model step is 0.1 by default but spiro only needs 1.0
set.model.step(iHandle, 1, 1)

# initialize the model, including default slider values
reset.model(iHandle, -2)

xs <- list(get.value.list(iHandle, "/runs/x"))
ys <- list(get.value.list(iHandle, "/runs/y"))
for (count in 1:1739) {
  execute.model(iHandle, count)
  xs[[count+1]] <- get.value.list(iHandle, "/runs/x")
  ys[[count+1]] <- get.value.list(iHandle, "/runs/y")
}
xs <- mapply(c,xs)
ys <- mapply(c,ys)
print("View default pattern -- now try to plot dancer")
plot(xs, ys, type="l")

# now we are going to parameterize it using a state file for the slider helper
# -- to make this work we load the mime library, which is needed only because
# the dancer.spf in Simile v5.94 is an older v4.x format file.

tcl("package","require","mime")
pFile  <- tcl("file", "join", path.to.installation, "Examples", "dancer.spf")
consult.parameter.metafile(iHandle, pFile)

# also the file from the distribution has no value for "Wheel outside?"
# so we set this boolean directly
pHandle <- create.param.array(iHandle, "/start/Wheel outside?")
set.model.parameter(pHandle, FALSE)

# apply reset at level 0 to propagate input values
reset.model(iHandle, 0)

xs <- list(get.value.list(iHandle, "/runs/x"))
ys <- list(get.value.list(iHandle, "/runs/y"))
for (count in 1:419) {
  execute.model(iHandle, count)
  xs[[count+1]] <- get.value.list(iHandle, "/runs/x")
  ys[[count+1]] <- get.value.list(iHandle, "/runs/y")
}
xs <- mapply(c,xs)
ys <- mapply(c,ys)
plot(xs, ys, type="l")

print("OK, but that's not how it looks on Simile is it? Try this...")
xs <- aperm(xs, c(2,1))
ys <- aperm(ys, c(2,1))
plot(xs, ys, type="l")
}
}
