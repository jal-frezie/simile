\name{list.objects}
\alias{list.objects}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
List Simile model components
}
\description{
Lists all the model components with values. Components are specified by
path, i.e., a string made from their caption preceded by the caption of
their parent submodel, its parent and so on, separated by
forward-slashes like a directory path.
}
\usage{
list.objects(model.handle)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{model.handle}{
    %%     ~~Describe \code{path.to.installation} here~~
    Model handle created when calling load.model()
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
List of component paths as described above, in tree traversal order}
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
%% q~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
\donttest{
% requires Simile installation plus saved executable model so cannot be
% auto tested
list.objects(model.handle)
# [1] "/sector"           "/sector/output"    "/sector/flow1"    
# [4] "/sector/variation"
}
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
