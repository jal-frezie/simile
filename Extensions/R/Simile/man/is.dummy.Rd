\name{is.dummy}
\alias{is.dummy}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Test if a path or handle is a 'dummy' whose only purpose is to allow
  tests to run.
}
\description{
When any of the functions in the package are called, if this returns
'true' on their first argument, no actual Simile interaction will be
attempted but some sample output may be returned.
}
\usage{
is.dummy(path.or.handle)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{path.or.handle}{
The file path or handle which is being tested for dummy-ness.
}
}
\value{
  A boolean which is true in the case of a dummy argument.
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

\examples{
is.dummy("dummy.dll")
# [1] TRUE
is.dummy("~/.simile/Examples/spiro.so")
# [1] FALSE
}