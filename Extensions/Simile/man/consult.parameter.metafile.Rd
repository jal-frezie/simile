\name{consult.parameter.metafile}
\alias{consult.parameter.metafile}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Set a model's parameters from a file saved by Simile
}
\description{
  Parameter metafiles (.spf) saved from within Simile can contain
  information about a model's parameter values, either locally or as
  references to other files. They may refer to the whole model or a submodel.
}
\usage{
consult.parameter.metafile(instance.handle,param.file)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
The handle returned by create.model() identifying the model instance.
}
  \item{param.file}{
Location of the parameter metafile.
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
  None
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\references{
%% ~put references to the literature/web site here ~
}
\author{
Jasper Taylor
}
\note{
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
consult.parameter.metafile(instance.handle, "../data/base_vals.spf")
}