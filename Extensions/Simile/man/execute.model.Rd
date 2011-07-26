\name{execute.model}
\alias{execute.model}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Execute a Simile model to a given time point 
}
\description{
The model will be executed using the time steps specified by earlier
calling set.model.step until either the finish time is reached or an
exception occurs.
}
\usage{
execute.model(instance.handle, integration.method, start.time, finish.time,
error.limit, pause.on.event)}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
    The handle returned by create.model(), identifying an executable model instance.
  }
  \item{integration.method}{
    One of "Euler" or "Runge-Kutta", the latter being 4th-order
  }
  \item{start.time}{
    Time returned by functions in the model on the first execution
    step. On each subsequent step this will be incremented by the value
    specified by earlier calling set.model.step
  }
  \item{finish.time}{
    Time returned by functions in the model on the last execution
    step, when incrementing the time takes it to or beyond this value. 
  }
  \item{error.limit}{Maximum integration error allowed by adaptive step
    size variation, as a fraction of the allowed
    range of each model compartment value. The integration error is
    estimated by comparing each compartment's rate of change with that
    predicted on the previous time step (equal to its previous rate of
    change if Euler). If error limit is exceeded, the time step is
    temporarily shortened and the model re-executed from the end of the
    last time step. If this argument is set to 0, no adaptive step
    size variation is done.}
  \item{pause.on.event}{Reserved for future Simile versions with
    discrete event handling.}
} 
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
  A list with two elements:
  \describe{
    \item{1}{Result code: value of system error (-ve), user-defined
      interruption (+ve) or 0 if model runs to finish.time}
    \item{2}{Time at which execution actually finished}
    }
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
execute.model(instance.handle, "Runge-Kutta", 0, 100, 1e-6, 0)
  [1] 0 100
}