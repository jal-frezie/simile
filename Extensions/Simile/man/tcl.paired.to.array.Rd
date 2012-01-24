\name{tcl.paired.to.array}
\alias{tcl.paired.to.array}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Re-format model value array
}
\description{
  Convert a set of values from a Simile model component from a nested
  list of alternating indices and values to an R array structure
}
\usage{
%- maybe also 'usage' for other objects documented here.
tcl.paired.to.array(paired, dims, as.enum.types)
}
\arguments{
  \item{paired}{
    Nested list of alternating indices and values
  }
  \item{dims}{
    Dimensions of R array structure
  }
  \item{as.enum.types}{
    If TRUE, values will be converted to R character strings, otherwise
    they are numeric
  }
}
\value{
  A numerical value or array of numerical values, from the Tcl value or array


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
Note that the dimensions of the array returned will be in the opposite
order from those supplied in the 'dims' argument. This is because
Simile's convention is to list the outermost dimension first, whereas
R's is to list the outermost dimension last.
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
  \code{\link{tcl.paired.to.list}}
}
\examples{
Simile:::tcl.paired.to.array("1 {1 7 2 4} 2 {1 8 2 6} 3 {1 9 2 1}",
c(3,2), FALSE)
#     [,1] [,2] [,3]
#[1,]    7    8    9
#[2,]    4    6    1
}
