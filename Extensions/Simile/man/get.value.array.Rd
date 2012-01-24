\name{get.value.array}
\alias{get.value.array}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Get values from model components
}
\description{
  Retrieves data from the model, as either a single quantity or an array
  of values with the appropriate dimensions
}
\usage{
%- maybe also 'usage' for other objects documented here.
get.value.array(instance.handle, value.name, as.enum.types)
}
\arguments{
  \item{instance.handle}{
    The handle returned by create.model(), identifying an executable model instance.
  }
  \item{value.name}{
    Caption path to the model component whose values are required
  }
  \item{as.enum.types}{
    Logical: whether to supply values as character strings, using
    enumerated type names if applicable. Default is false: values are numerical.
  }
}
\value{
  A value or array of values, from the model


%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\author{
Jasper Taylor
}
\note{
  %%  ~~further notes~~
  Will not work on components inside variable-membership submodels. For
  these you should use get.value.list instead, as R's list structure is
  more appropriate than the array structure when not all values exist.
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
  \code{\link{get.value.list}}
}
\examples{
\donttest{
% requires Simile installation plus saved executable model so cannot be
% auto tested
get.value.array(instance.handle,"/sector/output", FALSE)
 [1]  0.8414710  0.9092974  0.1411200 -0.7568025 -0.9589243 -0.2794155
 [7]  0.6569866  0.9893582  0.4121185 -0.5440211
}
}