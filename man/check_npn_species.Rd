% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/check_npn_species.r
\name{check_npn_species}
\alias{check_npn_species}
\title{Checks if USA-NPN species exists}
\usage{
check_npn_species(species = NULL, list = TRUE)
}
\arguments{
\item{species}{An USA-NPN species (character or number).
Will search in both Genus species and common name fields and will match
any term within those fields. The search relies on regular expressions so
this can be used to be more specific.}

\item{list}{List all species numbers and names as verbose output}
}
\value{
a validated list of species numbers, if not a warning is thrown
and any depended routines halted.
}
\description{
Checks if USA-NPN species exists
}
\examples{

\dontrun{
# list all USA-NPN phenophases
check_npn_species(species = 3, list = TRUE)
}
}
\keyword{model,}
\keyword{phenology,}
\keyword{preprocessing}
