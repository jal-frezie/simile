\name{get.model.property}
\alias{get.model.property}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Get properties of model components
}
\description{
This function can return any of several pieces of static information
about a component in a loaded Simile model}
\usage{
get.model.property(model.handle,caption.path,requested.property)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{model.handle}{
%%     ~~Describe \code{path.to.installation} here~~
    Model handle created when calling load.model()
}
\item{caption.path}{
  Path made from submodel and component captions separated by forward
  slashes, like a member of the list returned by list.objects()
}
\item{requested.property}{
  One of the following strings:
  \describe{
    \item{Class}{Returns the component class, i.e., which Simile symbol it is.}
    \item{Type}{Data type of component's value. }
    \item{Eval}{Source of component's value. }
    \item{Dims}{Returns list of the component value's array dimensions.}
    \item{MinVal, MaxVal, Desc, Comment}{Return other values or text associated
      with component in Simile.}
  }
}
}
\value{
  Form of returned value depends on the requested.property as described
  above.
  \itemize{
  \item For Class it is one of SUBMODEL VARIABLE COMPARTMENT FLOW CONDITION
CREATION REPRODUCTION IMMIGRATION LOSS ALARM EVENT SQUIRT STATE
\item For Type: one of VALUELESS REAL
INTEGER FLAG EXTERNAL or ENUM(n), where n is the index of a set of
enumerated type values.
\item For Eval: one of EXOGENOUS DERIVED
TABLE INPUT SPLIT GHOST. Fixed parameters have TABLE and variable
parameters INPUT for this property.
\item For Dims it is a list containing integers or the special types RECORDS
MEMBERS SEPARATE START_VM END_VM for components in submodels without a
preset member count.
\item For MinVal and MaxVal it is a number of the same type as the component.
\item For Desc and Comment it is a character string.
}
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
get.model.property("dummy_mh","/sector/output","Class")
# [1] "COMPARTMENT"
get.model.property("dummy_mh","/sector/output","Dims")
# [1] 2 5
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
