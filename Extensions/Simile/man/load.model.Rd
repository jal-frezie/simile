\name{load.model}
\alias{load.model}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Load a Simile executable model
}
\description{
Loads a simile model saved as a compiled binary ( a .dll, .so or .dylib
file depending on platform)
}
\usage{
load.model(path.to.binary)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{path.to.binary}{
    Absolute or relative path to file to be loaded
%%     ~~Describe \code{path.to.installation} here~~
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
  Handle to be used for querying or instantiating model, as a Tcl object
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
Jasper Taylor}
\note{
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
\donttest{
% requires Simile installation plus saved executable model so cannot be
% auto tested
model.handle <- load.model("~/My Simile files/Test/Scripting/mytest.dll")
}
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
