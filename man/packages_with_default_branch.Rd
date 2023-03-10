% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rename_branch_to_devel.R
\name{packages_with_default_branch}
\alias{packages_with_default_branch}
\title{Find packages with default branches for an organization}
\usage{
packages_with_default_branch(
  version = BiocManager::version(),
  branches = c("master", "main"),
  org = "Bioconductor"
)
}
\arguments{
\item{version}{\code{character(1)} The current development version of Bioconductor
given by \code{BiocManager::version()} (default). It is used to obtain the
packages currently available in the Bioconductor CRAN-like repository with
\code{BiocManager::repositories()}.}

\item{branches}{\code{character()} A vector of branches that are sought as default
branches}

\item{org}{\code{character(1)} The organization for which to extract the names of
the repositories on GitHub (default "Bioconductor").}
}
\value{
A named character vector of default branches whose names correspond
to package repositories on GitHub
}
\description{
This function will search through an organizations repositories and identify
packages whose default branches are in the \code{branches} argument. This allows
the user to identify which repositories will need to have a \code{devel} branch
added.
}
\details{
The output of this function is used in \code{rename_branch_packages}.
}
\seealso{
rename_branch_packages
}
