\name{get.model.time}
\alias{get.model.time}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Gets the time in the simulation.
}
\description{
The simulation time is initialized by the reset.model command, and
incremented by the execute.model command. After execute.model it may
not be the expected end time because the model may stop executing
before that point for various reasons.
}
\usage{
get.model.time(instance.handle)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
The handle returned by create.model(), identifying an executable model instance.
}
}
\value{
  The current model time
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
get.model.time("dummy_ih")
}