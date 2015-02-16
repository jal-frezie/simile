\name{reset.model}
\alias{reset.model}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  resets the model to its initial state. 
}
\description{
A Simile model instance must be reset before it is first run, whenever
the parameters are changed, and in order to run it again with new values
for random constants.
}
\usage{
reset.model(instance.handle, depth, integration.method, starting.time)}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
    The handle returned by create.model(), identifying an executable model instance.
  }
  \item{depth}{
    Simile does a sort of 'lazy execution', with values being left
    untouched if they do not need to be recalculated for a given type of
    reset. This argument tells it what to reset, with each action
    including those that follow it:
    \describe{
    \item{-2}{Recalculate constant atrithmetic expressions including numerals}
    \item{-1}{Recalculate values that depend on fixed parameters}
    \item{0}{Recalculate random constants and set state variables to their
    initial values}
    \item{+ve}{Recalculate rate variables from the current state values at this
      time step}
    }
  }
  \item{integration.method}{
    One of "Euler" or "Runge-Kutta", the latter being 4th-order. Default
    is "Euler".
  }
  \item{starting.time}{
    Value for model time after resetting. Used for indexing time series,
    time plots etc in the model. Default is 0. 
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
reset.model("dummy_ih", -2)
}