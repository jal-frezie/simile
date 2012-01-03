\name{create.model}
\alias{create.model}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Create an executable model instance
}
\description{
A script can create many independent instances of the same model
description, each with its own execution state.
}
\usage{
create.model(model.handle)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{model.handle}{
The handle returned by load.model() identifying the model type.
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
  A handle to a new instance of the model, which will have its own
  component values, parameter values and execution settings
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
\donttest{
% requires Simile installation plus saved executable model so cannot be
% auto tested
instance.handle <- create.model(model.handle)
}
}