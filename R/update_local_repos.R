#' Update local repositories after GitHub branch rename
#'
#' These functions works _only_ after renaming branches on GitHub from `master`
#' to `devel`. It updates local folders so that branches are renamed to `devel`
#' locally. It also ensures that the `HEAD` is pointing to the new remote
#' location, i.e., `origin/devel` (see `gert::git_remote_info()$head`). For
#' convenience, the singular `update_local_repo` function will update a
#' particular local repository on the user's system.
#'
#' @details Note that `update_local_repos` (plural) queries the GitHub API to
#'   discover repositories whose default branches are set to `devel`. The
#'   function then matches those repository names with local folder names under
#'   `basedir` and performs the necessary steps to rename the branch and set the
#'   `HEAD` to `origin/devel`. The singular function `update_local_repo` assumes
#'   that the remote change has been made and will rename the local branch and
#'   update the local repository to match the remote 'HEAD'.
#'
#' @param basedir `character(1)` The base directory where all packages /
#'   repositories exist for the user
#'
#' @param repo_dir `character(1)` The full path to the directory of the local
#'   repository whose default branch should be updated
#'
#' @param username `character(1)` (optional) The GitHub username used in the
#'   query to check default packages
#' 
#' @inheritParams gert::git_branch_move
#' @inheritParams rename_branch_repos
#' @importFrom ReleaseLaunch get_user_github_repos
#'
#' @export
update_local_repos <- function(
    basedir, org = "Bioconductor", username,
    new_branch = "devel", set_upstream = "origin/devel"
) {
    if (!missing(username)) {
        repos <- ReleaseLaunch::get_user_github_repos(username = username)
        org <- username
    } else {
        repos <- ReleaseLaunch::get_org_github_repos(org = org)
    }
    repos <- repos[repos == new_branch]
    folders <- list.dirs(basedir, recursive = FALSE)
    pkg_dirs <- folders[basename(folders) %in% names(repos)]
    
    is_bioc <- .is_bioc_pkgs(pkg_dirs)

    if (!length(matching))
        stop("No local folders in 'basedir' to update")

    mapply(
        FUN = update_local_repo,
        repo_dir = pkg_dirs,
        is_bioc = is_bioc,
        MoreArgs = list(
            new_branch = new_branch,
            set_upstream = set_upstream,
            org = org
        ),
        SIMPLIFY = FALSE
    )
}

#' @rdname update_local_repos
#'
#' @param is_bioc `logical(1)` Whether the repository in question is a
#'   Bioconductor package
#'
#' @export
update_local_repo <- function(
        repo_dir,
        is_bioc,
        new_branch = "devel",
        set_upstream = "origin/devel",
        org = "Bioconductor"
) {
    old_wd <- setwd(repo_dir)
    on.exit({ setwd(old_wd) })
    message("Working on: ", repo_dir)
    if (git_branch_exists(new_branch))
        return(git_branch_checkout(new_branch))
    from_branch <- git_branch()
    if (!identical(from_branch, "master"))
        git_branch_checkout("master")
    git_branch_move(
        branch = from_branch, new_branch = new_branch, repo = I(".")
    )
    if (!.is_origin_github(org = org))
        stop("'origin' remote should be set to GitHub")
    git_fetch(remote = "origin")
    system2("git", "remote set-head origin -a")
    git_branch_set_upstream(set_upstream)
}

.is_origin_github <- function(remotes, org) {
    if (missing(remotes))
        remotes <- git_remote_list()
    remote_url <- unlist(remotes[remotes[["name"]] == "origin", "url"])
    grepl(paste0("github.com:", org), remote_url, ignore.case = TRUE)
}

#' A helper function to adjust git remotes the Bioconductor way
#'
#' This function will update a repository's remotes by setting `origin` to the
#' GitHub location and `upstream` to the Bioconductor git server.
#'
#' @inheritParams update_local_repo
#'
#' @return Called for the side-effect of adjusting `git remotes` in the
#'   `repo_dir`; check them with `git remote -v`
#'
#' @export
fix_bioc_remotes <- function(repo_dir, org = "Bioconductor", is_bioc) {
    old_wd <- setwd(repo_dir)
    on.exit({ setwd(old_wd) })
    
    remotes <- git_remote_list()
    if (!.is_origin_github(remotes, org))
        stop("'origin' GitHub remote does not include ", org)
    
    if (!.has_bioc_upstream(remotes) && is_bioc)
        git_remote_add(.get_bioc_slug(basename(repo_dir)), name = "upstream")
    
    if (is_bioc)
        .validate_remotes()
}

.is_bioc_pkgs <- function(pkg_dirs) {
    bioc_pkgs <- rownames(
        available.packages(repos = BiocManager::repositories()["BioCsoft"])
    )
    basename(pkg_dirs) %in% pkg_dirs
}