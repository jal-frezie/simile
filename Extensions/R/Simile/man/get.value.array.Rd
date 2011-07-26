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
get.value.array(instance.handle, value.name)
}
\arguments{
  \item{instance.handle}{
    The handle returned by create.model(), identifying an executable model instance.
  }
  \item{value.name}{
    Caption path to the model component whose values are required
  }
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
  A numerical value or array of numerical values, from the model


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
get.value.array(instance.handle,"/sector/output")
 [1]  0.8414710  0.9092974  0.1411200 -0.7568025 -0.9589243 -0.2794155
 [7]  0.6569866  0.9893582  0.4121185 -0.5440211
}