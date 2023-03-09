#' Convenience function to create the devel branch for all GitHub packages
#'
#' This function identifies an organization's repositories that are packages
#' given the current version of Bioconductor (from `BiocManager::version()`)
#' and identifies which repositories need to have a `devel` branch added.
#' It then adds the `devel` branch using the `rename_branch_to_devel` function.
#' It is highly recommended that the user run this on the devel version of
#' Bioconductor to avoid missing packages that are only in devel.
#'
#' @details
#'
#' Note that the `clone` argument allows the user to clone the repository first
#' from GitHub via SSH. It is recommended that this be enabled and that the
#' user running this function can clone packages via SSH and have access to
#' modifying packages on the GitHub organization.
#'
#' @inheritParams rename_branch_to_devel
#'
#' @inheritParams packages_with_default_branch
#'
#' @param packages `named character()` A character vector of default branches
#'   whose names correspond to Bioconductor package names. See
#'   `packages_with_default_branch`.
#'
#' @param old_branches `character()` A vector of default branch names to be
#'   replaced, both 'master' and 'main' are included by default. This argument
#'   only works when either `packages` or `repos` are not specified.
#'
#' @seealso packages_with_default_branch
#'
#' @export
rename_branch_packages <- function(
    packages = character(0L),
    version = BiocManager::version(),
    old_branches = c("master", "main"),
    org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = TRUE
) {
    if (!length(packages))
        packages <- packages_with_default_branch(version, old_branches, org)
    if (is.null(names(packages)))
        stop("'packages' must have names")
    .rename_branch_to_devel(
        packages = packages,
        org = org,
        set_upstream = set_upstream,
        clone = clone,
        is_bioc_pkg = TRUE
    )
}
