\name{set.model.step}
\alias{set.model.step}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Sets the time step used to execute a model.
}
\description{
The time step is the amount by which the model time advances each time
the state variables are updated. A model may have more than one time
step.
}
\usage{
set.model.step(instance.handle,step.index,step.size)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
The handle returned by create.model(), identifying an executable model instance.
}
  \item{step.index}{
The level of the time step to be set. If a model only has one time step,
this is step 1. Higher levels are set to shorter steps.
}
\item{step.size}{
  The duration for the time step.
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
set.model.step("dummy_ih", 1, 0.1)
}