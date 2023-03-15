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
#' @param branches `character()` A vector of branches that are sought as default
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
    branches = c("master", "main"),
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
    branches = c("master", "main"),
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
#' @param from_branch `character(1)` The old default branch from which to base
#'   the new 'devel' branch from (default: 'master')
#'
#' @param set_upstream `character(1)` The remote location that will be tracked
#'   by the local branch, either "origin/devel" (default) or "upstream/devel"
#'
#' @param clone `logical(1)` Whether to clone the GitHub repository into the
#'   current working directory (default: TRUE)
#'
#' @param is_bioc_pkg `logical(1)` Whether the repository is an R package that
#'   has an upstream remote on Bioconductor, i.e.,
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
    package_name, from_branch = "master", org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = FALSE, is_bioc_pkg = TRUE
) {
    message("Working on: ", package_name)
    if (!dir.exists(package_name) && clone)
        git_clone(url = .get_gh_slug(package_name, org))
    else if (!dir.exists(package_name))
        stop("'package_name' not found in the current 'getwd()'")

    old_wd <- setwd(package_name)
    on.exit({ setwd(old_wd) })
    
    if (clone && !.has_bioc_upstream() && is_bioc_pkg)
        git_remote_add(url = .get_bioc_slug(package_name), name = "upstream")
    
    if (is_bioc_pkg && !clone)
        .validate_remotes()

    has_old <- git_branch_exists(from_branch)
    has_devel <- git_branch_exists("devel")
    if (has_devel)
        warning("'devel' branch exists locally")

    git_fetch(remote = "origin")
    if (!has_old && !has_devel) {
        stop("Neither '", from_branch, "' nor 'devel' branch was found")
    }
    git_pull(remote = "origin")
    if (is_bioc_pkg)
        git_pull(remote = "upstream")
    if (!has_devel)
        git_branch_move(
            branch = from_branch, new_branch = "devel", repo = I(".")
        )
    if (git_branch_exists(from_branch) && git_branch_exists("devel")) {
        git_branch_checkout("devel")
        warning(
            "Check '", from_branch,
            "' for uncommitted changes and delete with\n",
            "  git branch -d ", from_branch
        )
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
