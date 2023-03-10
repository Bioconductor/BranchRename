## Use this helper to format all error / warning / message text
.msg <-
    function(fmt, ..., width=getOption("width"))
{
    strwrap(sprintf(fmt, ...), width=width, exdent=4)
}

.check_remote_exists <- function(remotes, remote) {
    remote %in% remotes[["name"]]
}

.get_bioc_slug <- function(package_name) {
    paste0(.BIOC_GIT_ADDRESS, ":packages/", package_name)
}

.get_gh_slug <- function(package_name, org = "Bioconductor") {
    paste0(.GITHUB_ADDRESS, ":", org, "/", package_name)
}

.validate_bioc_remote <- function(remotes, remote = "upstream") {
    bioc_remote <- .has_bioc_upstream(remotes)
    if (!bioc_remote)
        stop(
            sQuote(remote, FALSE),
            " remote not set to Bioconductor git repository"
        )
}

.validate_remote_names <- function(remotes) {
    all_remotes <- all(c("origin", "upstream") %in% remotes[["name"]])
    if (!all_remotes)
        stop("'origin' and 'upstream' remotes are not set")
}

.validate_remotes <- function() {
    remotes <- git_remote_list()
    .validate_remote_names(remotes)
    .validate_bioc_remote(remotes)
    TRUE
}

.has_bioc_upstream <- function(remotes) {
    if (missing(remotes))
        remotes <- git_remote_list()
    remote_url <- unlist(
        remotes[remotes[["name"]] == "upstream", "url"]
    )
    if (length(remote_url))
        grepl("git.bioconductor.org", remote_url)
    else
        FALSE
}
