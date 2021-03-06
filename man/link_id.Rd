\name{link_id}
\alias{link_id}
\title{Get the id's of listeners on linking}
\usage{
link_id(data = last_data())
}
\arguments{
  \item{data}{a mutaframe created by \code{\link{qdata}}
  (default to be \code{\link{last_data}()}, i.e. the lastly
  used data)}
}
\value{
  A character vector of id's.
}
\description{
  This function returns the id's of listeners attached on a
  data for linking, and these id's can be used to remove
  the linking.
}
\examples{
## see ?link_cat
}
\author{
  Yihui Xie <\url{http://yihui.name}>
}
