\name{tcl.paired.to.list}
\alias{tcl.paired.to.list}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Re-format model value array
}
\description{
  Convert a set of values from a Simile model component from a nested
  list of alternating indices and values to an R nested list structure
}
\usage{
%- maybe also 'usage' for other objects documented here.
tcl.paired.to.list(paired, as.enum.types)
}
\arguments{
  \item{paired}{
    Nested list of alternating indices and values
  }
  \item{as.enum.types}{
    If TRUE, indices and values will be converted to R character
    strings, otherwise they are numeric
  }
}
\value{
  A numerical value or nested list of numerical values, from the Tcl value or array


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
  \code{\link{tcl.paired.to.array}}
}
\examples{
Simile:::tcl.paired.to.list("1 {1 7 2 4} 2 {1 8} 3 {2 1}", FALSE)
# [[1]]
# [[1]][[1]]
# [1] 7
# 
# [[1]][[2]]
# [1] 4
# 
# 
# [[2]]
# [[2]][[1]]
# [1] 8
# 
# 
# [[3]]
# [[3]][[1]]
# NULL
# 
# [[3]][[2]]
# [1] 1
}
\keyword{internal}