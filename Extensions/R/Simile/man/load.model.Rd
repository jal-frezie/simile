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
\value{
  Handle to be used for querying or instantiating model, as a Tcl object
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\author{
Jasper Taylor}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\examples{
model.handle <- load.model("dummy.dll")
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
