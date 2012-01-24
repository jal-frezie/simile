\name{execute.model}
\alias{execute.model}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Execute a Simile model to a given time point 
}
\description{
The model will be executed using the time steps specified by earlier
calling set.model.step until either the finish.time is reached or an
exception occurs.
}
\usage{
execute.model(instance.handle, finish.time, integration.method,
start.time, error.limit, pause.on.event)}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{instance.handle}{
    The handle returned by create.model(), identifying an executable model instance.
  }
  \item{finish.time}{
    Time returned by functions in the model on the last execution
    step, when incrementing the time takes it to or beyond this value. 
  }
  \item{integration.method}{
    One of "Euler" or "Runge-Kutta", the latter being 4th-order. Default
    is "Euler".
  }
  \item{start.time}{
    Time returned by functions in the model on the first execution
    step. On each subsequent step this will be incremented by the value
    specified by earlier calling set.model.step. Default is NA, which starts the
    model at the time to which it was previously reset or executed.
  }
  \item{error.limit}{Maximum integration error allowed by adaptive step
    size variation, as a fraction of the allowed
    range of each model compartment value. The integration error is
    estimated by comparing each compartment's rate of change with that
    predicted on the previous time step (equal to its previous rate of
    change if integration method is Euler). If error limit is exceeded,
    the time step is temporarily shortened and the model re-executed
    from the end of the last time step. Default is 0, in which case no
    adaptive step size variation is done.}
  \item{pause.on.event}{Reserved for future Simile versions with
    discrete event handling. Default is FALSE.}
} 
\value{
  Result code: value of system error (-ve), user-defined
      interruption (+ve) or 0 if model runs to finish.time
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

