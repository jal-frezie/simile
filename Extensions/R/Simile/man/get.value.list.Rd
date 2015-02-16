\name{get.value.list}
\alias{get.value.list}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Get values from model components
}
\description{
  Retrieves data from the model, as either a single quantity or a
  possibly nested list of values
}
\usage{
%- maybe also 'usage' for other objects documented here.
get.value.list(instance.handle, value.name, as.enum.types)
}
\arguments{
  \item{instance.handle}{
    The handle returned by create.model(), identifying an executable model instance.
  }
  \item{value.name}{
    Caption path to the model component whose values are required
  }
  \item{as.enum.types}{
    Logical: whether to supply indices and values as character strings, using
    enumerated type members if applicable. Default is false: indices are
    integers and values are numerical.
  }
}
\value{
  A value or index-value list, from the model


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

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
  \code{\link{get.value.array}}
}
\examples{
get.value.list("dummy_ih", "/runs/x", "FALSE")
# [[1]]
# [1] 40.76668
# 
# [[2]]
# [1] 37.52907
# 
# [[3]]
# [1] 33.82021
# 
# [[4]]
# [1] 29.69413
}