#' A convenience function to set the 'upstream' Bioconductor remote
#'
#' The function will create an 'upstream' remote using
#' `git@git.bioconductor.org` as the primary address. If an `upstream` remote
#' already exists, it will be validated. The remote name can be changed to the
#' desired name via the `remote` argument but it is customarily called the
#' 'upstream' remote.
#'
#' @param package_path `character(1)` The local path to a package directory
#'   whose upstream remote should be set
#'
#' @param remote `character(1)` The name of the remote to be created. This is
#'   usually named 'upstream' (default)
#'
#' @return Called for the side effect of creating an 'upstream' remote with the
#'   Bioconductor git address for a given package
#'
#' @export
add_bioc_remote <- function(package_path, remote = "upstream") {
    old_wd <- setwd(package_path)
    on.exit({ setwd(old_wd) })

    remotes <- git_remote_list()
    has_remote <- .check_remote_exists(remotes, remote)
    if (has_remote)
        return(
            .validate_bioc_remote(remotes, remote)
        )

    ## add upstream to Bioc
    bioc_git_slug <- .get_bioc_slug(basename(package_path))

    git_remote_add(bioc_git_slug, remote)
}