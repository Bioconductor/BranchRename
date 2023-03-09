#' Convenience function to create the devel branch for all GitHub repositories
#'
#' This function identifies all repositories within an organization that have
#' `old_branches`, i.e., either 'master' or 'main' by default. It then
#' sets the default branch to `devel`.
#'
#' @inheritParams rename_branch_packages
#'
#' @param repos `named character()` A vector of default branches whose names
#'   correspond to repositories hosted on GitHub. If missing,
#'   `repos_with_default_branch` is called and its result is used.
#'
#' @seealso repos_with_default_branch
#'
#' @export
rename_branch_repos <- function(
    repos = character(0L),
    old_branches = c("master", "main"),
    org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = TRUE
) {
    if (!length(repos))
        repos <- repos_with_default_branch(old_branches, org)
    if (is.null(names(repos)))
        stop("'repos' must have names")
    .rename_branch_to_devel(
        packages = repos,
        org = org,
        set_upstream = set_upstream,
        clone = clone,
        is_bioc_pkg = FALSE
    )
}
