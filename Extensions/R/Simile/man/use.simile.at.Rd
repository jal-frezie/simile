\name{use.simile.at}
\alias{use.simile.at}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Initialize the Simile interface
}
\description{
This tells the package where to find an installed copy of Simile. It
then loads the Tcl command implementations in the Simile installation to
enable R's tcltk package to communicate with Simile's saved executable
models. It should be called only once in a session.
}
\usage{
use.simile.at(path.to.installation)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{path.to.installation}{
Absolute or realtive path to top directory of Simile installation
  }
}
\value{
  undefined.
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\author{
  Simulistics Ltd
}
\examples{
\donttest{
% requires Simile installation so cannot be auto tested
use.simile.at("c:/Program files/Simile5.9")
}
}
