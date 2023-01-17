.OLD_DEFAULT_BRANCH <- "master"
.BIOC_GIT_ADDRESS <- "git@git.bioconductor.org"
.GITHUB_ADDRESS <- "git@github.com"

#' Find packages with default branches for an organization
#'
#' This function will search through an organizations repositories and identify
#' packages whose default branches are in the `branches` argument. This allows
#' the user to identify which repositories will need to have a `devel` branch
#' added.
#'
#' @details The output of this function is used in `rename_branch_packages`.
#'
#' @inheritParams rename_branch_to_devel
#'
#' @param version `character(1)` The current development version of Bioconductor
#'   given by `BiocManager::version()` (default). It is used to obtain the
#'   packages currently available in the Bioconductor CRAN-like repository with
#'   `BiocManager::repositories()`.
#'
#' @param branches character() A vector of branches that are sought as default
#'   branches
#'
#' @seealso rename_branch_packages
#'
#' @return A named character vector of default branches whose names correspond
#'   to package repositories on GitHub
#'
#' @import gert
#' @importFrom ReleaseLaunch get_org_github_repos
#' @importFrom utils available.packages
#'
#' @export
packages_with_default_branch <- function(
    version = BiocManager::version(),
    branches = c(.OLD_DEFAULT_BRANCH, "main"),
    org = "Bioconductor"
) {
    repos <- BiocManager:::.repositories_bioc(version)["BioCsoft"]
    db <- utils::available.packages(repos = repos, type = "source")
    software <- rownames(db)
    pre_existing_pkgs <- ReleaseLaunch::get_org_github_repos(org = org)
    candidates <- intersect(names(pre_existing_pkgs), software)
    candidates <- pre_existing_pkgs[candidates]
    candidates[candidates %in% branches]
}

#' Identify repositories that have old default branches
#'
#' The function obtains all the repositories within the given organization
#' (Bioconductor) that match the `branches` argument.
#'
#' @details The output of this function is used to rename branches with
#'   `rename_branch_repos`.
#'
#' @inheritParams packages_with_default_branch
#'
#' @return A named character vector of default branches whose names correspond
#'   to organization repositories on GitHub
#'
#' @seealso rename_branch_repos
#'
#' @export
repos_with_default_branch <- function(
    branches = c(.OLD_DEFAULT_BRANCH, "main"),
    org = "Bioconductor"
) {
    repos <- ReleaseLaunch::get_org_github_repos(org = org)
    repos[repos %in% branches]
}

#' Create the 'devel' branch locally and on GitHub
#'
#' The function is meant to be run one level up from the local git repository.
#' It will create the 'devel' branch and push to the `origin` remote which
#' should be set to GitHub. Upstream tracking can be configured to either the
#' `origin` or `upstream` remote.
#'
#' @details The `origin` remote is assumed to be GitHub, i.e.,
#'   `git@github.com:user/package` but this requirement is not checked or
#'   enforced; thus, allowing flexibility in remote `origin` locations. The
#'   `upstream` remote is validated against the Bioconductor git repository
#'   address, i.e., `git@git.bioconductor.org:packages/package`. The local
#'   repository is validated before the `devel` branch is created.
#'
#' @inheritParams ReleaseLaunch::`branch-release-gh`
#'
#' @param from_branch `character(1)` The old default branch from which to base the
#'   new 'devel' branch from (default: 'master')
#'
#' @param set_upstream `character(1)` The remote location that will be tracked by
#'   the local branch, either "origin/devel" (default) or "upstream/devel"
#'
#' @param clone logical(1) Whether to clone the GitHub repository into the
#'   current working directory (default: TRUE)
#'
#' @param is_bioc_pkg logical(1) Whether the repository is an R package that has
#'   an upstream remote on Bioconductor, i.e.,
#'   <git@git.bioconductor.org:packages/Package>. If so, additional validity
#'   checks will be run on the git remotes.
#'
#' @return Called for the side effect of creating a 'devel' branch on the local
#'   and remote repositories on GitHub
#'
#' @examples
#' if (interactive()) {
#'
#'   rename_branch_to_devel(
#'     package_name = "SummarizedExperiment",
#'     org = "Bioconductor",
#'     set_upstream = "upstream/devel"
#'   )
#'
#' }
#'
#' @export
rename_branch_to_devel <- function(
    package_name, from_branch = .OLD_DEFAULT_BRANCH, org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = FALSE, is_bioc_pkg = TRUE
) {
    message("Working on: ", package_name)
    if (!dir.exists(package_name) && clone)
        git_clone(url = .get_slug_gh(package_name, org))
    else if (!dir.exists(package_name))
        stop("'package_name' not found in the current 'getwd()'")

    old_wd <- setwd(package_name)
    on.exit({ setwd(old_wd) })
    if (is_bioc_pkg)
        .validate_remotes()

    has_devel <- git_branch_exists("devel")
    if (has_devel)
        warning("'devel' branch exists locally")

    git_fetch(remote = "origin")
    if (!git_branch_exists(from_branch))
        git_branch_create(from_branch)
    git_branch_checkout(from_branch)
    git_pull(remote = "origin")
    if (is_bioc_pkg)
        git_pull(remote = "upstream")
    if (!has_devel)
        git_branch_move(
            branch = from_branch, new_branch = "devel", repo = I(".")
        )
    if (git_branch_exists(from_branch) && git_branch_exists("devel")) {
        git_branch_checkout("devel")
        git_branch_delete(from_branch)
    }
    gh::gh(
        "POST /repos/{owner}/{repo}/branches/{branch}/rename",
        owner = org,
        repo = package_name,
        branch = from_branch, new_name = "devel",
        .token = gh::gh_token()
    )

    set_upstream <- match.arg(set_upstream)
    ## push first then set upstream
    git_push(remote = "origin")

    ## set head to origin/devel
    system2("git", "remote set-head origin devel")
    git_branch_set_upstream(set_upstream)
}

#' A convenience function to set the 'upstream' Bioconductor remote
#'
#' The function will create an 'upstream' remote using
#' `git@git.bioconductor.org` as the primary address. If an `upstream` remote
#' already exists, it will be validated. The remote name can be changed to the
#' desired name via the `remote` argument but it is customarily called the
#' 'upstream' remote.
#'
#' @param package_path character(1L) The local path to a package directory whose
#'   upstream remote should be set
#'
#' @param remote character(1L) The name of the remote to be created. This is
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

.rename_branch_to_devel <- function(
    packages,
    org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = TRUE,
    is_bioc_pkg = TRUE
) {
    mapply(
        FUN = rename_branch_to_devel,
        package_name = names(packages),
        from_branch = packages,
        MoreArgs = list(
            org = org,
            set_upstream = set_upstream,
            clone = clone,
            is_bioc_pkg = is_bioc_pkg
        ),
        SIMPLIFY = FALSE
    )
}

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
#' @param packages named character() A character vector of default branches
#'   whose names correspond to Bioconductor package names. See
#'   `packages_with_default_branch`.
#'
#' @param old_branches character() A vector of default branch names to be
#'   replaced, both 'master' and 'main' are included by default. This argument
#'   only works when either `packages` or `repos` are not specified.
#'
#' @seealso packages_with_default_branch
#'
#' @export
rename_branch_packages <- function(
    packages = character(0L),
    version = BiocManager::version(),
    old_branches = c(.OLD_DEFAULT_BRANCH, "main"),
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

#' Convenience function to create the devel branch for all GitHub repositories
#'
#' This function identifies all repositories within an organization that have
#' `old_branches`, i.e., either 'master' or 'main' by default. It then
#' sets the default branch to `devel`.
#'
#' @inheritParams rename_branch_packages
#'
#' @param repos named character() A vector of default branches whose names
#'   correspond to repositories hosted on GitHub. If missing,
#'   `repos_with_default_branch` is called and its result is used.
#'
#' @seealso repos_with_default_branch
#'
#' @export
rename_branch_repos <- function(
    repos = character(0L),
    old_branches = c(.OLD_DEFAULT_BRANCH, "main"),
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
#' @param username `character(1)` (optional) The GitHub username used in the query
#'   to check default packages
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
    if (!missing(username))
        repos <- ReleaseLaunch::get_user_github_repos(username = username)
    else
        repos <- ReleaseLaunch::get_org_github_repos(org = org)
    repos <- repos[repos == new_branch]
    folders <- list.dirs(basedir, recursive = FALSE)
    fnames <- basename(folders)
    matching <- intersect(fnames, names(repos))
    pkg_dirs <- file.path(basedir, matching)
    
    if (!length(matching))
        stop("No local folders in 'basedir' to update")

    mapply(
        FUN = update_local_repo,
        package_dir = pkg_dirs,
        MoreArgs = list(
            new_branch = new_branch,
            set_upstream = set_upstream
        ),
        SIMPLIFY = FALSE
    )
}

#' @rdname update_local_repos
#'
#' @export
update_local_repo <- function(
        repo_dir, new_branch = "devel", set_upstream = "origin/devel"
) {
    old_wd <- setwd(repo_dir)
    on.exit({ setwd(old_wd) })
    if (git_branch_exists(new_branch))
        return(git_branch_checkout(new_branch))
    from_branch <- git_branch()
    git_branch_move(
        branch = from_branch, new_branch = new_branch, repo = I(".")
    )
    if (!.is_remote_github())
        stop("'origin' remote should be set to GitHub")
    git_fetch(remote = "origin")
    system2("git", "remote set-head origin -a")
    git_branch_set_upstream(set_upstream)
}

.is_remote_github <- function(remote = "origin") {
    remotes <- git_remote_list()
    remote_url <- unlist(remotes[remotes[["name"]] == remote, "url"])
    grepl("github", remote_url, ignore.case = TRUE)
}
