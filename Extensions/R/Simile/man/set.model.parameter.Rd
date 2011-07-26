\name{set.model.parameter}
\alias{set.model.parameter}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Sets a model parameter with data in an array
}
\description{
A model parameter may be a single value or an array of values. This
function allows it to be set.
}
\usage{
set.model.parameter(param.handle,data)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{param.handle}{
The handle returned by create.param.array() identifying the location to
send the data.
}
  \item{data}{
The data to be used in the model, either a single value or an array with
the appropriate dimensions
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
set.model.parameter(param.handle, array(c(4,4,3,4,2,5,5,2,1,5), c(2,5)))
}