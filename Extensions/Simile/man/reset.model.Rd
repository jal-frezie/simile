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
reset.model(instance.handle, starting.time, integration.method, depth)}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
    The handle returned by create.model(), identifying an executable model instance.
  }
  \item{starting.time}{
    Value for model time after resetting. Used for indexing time series,
    time plots etc in the model.
  }
  \item{integration.method}{
    One of "Euler" or "Runge-Kutta", the latter being 4th-order
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
reset.model(instance.handle, 0, "Euler", -2)
}