\name{create.param.array}
\alias{create.param.array}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Allocates memory for interactively loading model parameters
}
\description{
If a script is to provide values directly for a Simile model parameter,
this command must be called first to set up a location for the
parameters to be held
}
\usage{
create.param.array(instance.handle,param.name)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
The handle returned by create.model() identifying the model instance.
}
  \item{param.name}{
Caption path to the model component whose value is to be specified
}
}
\value{
  A handle to the location that has been created.
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
param.handle <- create.param.array("dummy_ih", "/submodel1/trees/larch")
}
