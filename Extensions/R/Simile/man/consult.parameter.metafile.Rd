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
consult.parameter.metafile(instance.handle,param.file,target.submodel="")
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
The handle returned by create.model() identifying the model instance.
}
  \item{param.file}{
Location of the parameter metafile.
}
  \item{target.submodel}{
Pathname of the submodel into which the parameters are to be loaded. Default is the top level.
}
}
\value{
  None
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\author{
Jasper Taylor
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\examples{
\donttest{
% requires Simile installation plus saved executable model so cannot be
% auto tested
consult.parameter.metafile(instance.handle, "../data/base_vals.spf")
}
}
