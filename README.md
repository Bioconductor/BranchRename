
# GitHub Installation

``` r
if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install("Bioconductor/BranchRename")
```

## Loading the package

``` r
library(BranchRename)
```

# A Brief Description

`BranchRename` offers both organization and user-level tools for
renaming default branches on GitHub. It also interacts with local
repositories that need to be sync’ed with remote GitHub repositories.

# Setup

## Authentication

First, on GitHub, create a fine-grained Personal Access Token (PAT)
under User \> Settings \> Developer Settings \> PATs \> Fine-grained
tokens.

When generating a new token, select `Bioconductor` (or organization) as
the resource owner, then ‘All repositories’ and under ‘Repository
permissions’ select ‘Contents’ \> ‘Read and Write’ and also select ‘Read
and Write’ under ‘Administration’. It is recommended to use
`gitcreds::gitcreds_set()` to store ’the fine-grained PAT and to save
the token using Seahorse (Ubuntu) or other credentials management
application native to your operating system.

**Note**. Depending on the organization’s settings, R / Bioconductor
packages hosted on GitHub may also be updated with a classic PAT. These
commands only work if the user has admin access to the organization’s
GitHub account.

# Steps

## Identify repositories

The Bioconductor organization on GitHub hosts repositories that may also
be packages in Bioconductor. To identify packages containing the old
default branch name use the `packages_with_default_branch()` function.
To identify repositories that use the old default branch use the
`repos_with_default_branch()` function.

**Note**. The functions by default identify repositories with both
`master` and `main` as the default branch.

## Rename branch in GitHub repository

### Single package

The `rename_branch_to_devel` function allows users to rename the default
branch of a single package hosted by an organization on GitHub. For
example, here we attempt to change the default branch from `master` to
`devel` and ensure that upstream tracking is set to `origin/devel` or
`upstream/devel`:

``` r
rename_branch_to_devel(
    package_name = "SummarizedExperiment",
    from_branch = "master",
    org = "Bioconductor",
    set_upstream = "origin/devel",
    clone = TRUE
)
```

Note that `origin` and `upstream` refer to the GitHub and Bioconductor
git (i.e., on \<git.bioconductor.org\>) repositories, respectively.

### Batch of packages

To rename branches for multiple packages, it is first recommended to use
the `packages_with_default_branch()` to identify the groups of packages
under the organization that need to have their branches renamed. The
output of that function will provide a named character vector, e.g.,
`c(SummarizedExperiment = "master", GenomicRanges = "master")` where the
values are the default branch names and the names are the package names.

``` r
pkgs <- packages_with_default_branch()
```

With the named character vector, one can use the
`rename_branch_packages` function to perform the rename:

``` r
rename_branch_packages(packages = pkgs)
```

Similar operations can be performed with both
`repos_with_default_branch` and `rename_branch_repos`.

Both sets of functions work similarly but differ by package status.
Bioconductor packages are expected to have an `upstream` git remote that
points to \<git.bioconductor.org\>.

## Local repository update

For local repositores that were missed, e.g., when the
`rename_branch_to_devel` or the `rename_branch_packages` functions were
run with `clone = TRUE` in a separate directory, the old repositories
would need the local branches to be updated to the new name. The
`update_local_repo` function allows the user to perform the rename
operation locally and sync the repository to the GitHub remote
repository (in other words set the `HEAD` to track `origin/devel`).

``` r
update_local_repo(
    repo_dir = "~/bioc/SummarizedExperiment",
    new_branch = "devel",
    set_upstream = "origin/devel"
)
```

The function `update_local_repos` allows these type of updates for
multiple repositories within a given directory (`basedir`).

### Utilties

The `add_bioc_remote` is a convenience function that creates an
`upstream` remote for a given local git repository. This is useful only
for packages that are in \<git.bioconductor.org\> whose local
repositories do not have an `upstream` remote. The `add_bioc_remote()`
function is equivalent to:

``` sh
git remote add upstream git@git.bioconductor.org:packages/<MyPackage>
```

# Session Info

``` r
sessionInfo()
#> R Under development (unstable) (2022-10-24 r83173)
#> Platform: x86_64-pc-linux-gnu (64-bit)
#> Running under: Ubuntu 22.04.1 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/blas/libblas.so.3.10.0
#> LAPACK: /usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3.10.0
#> 
#> locale:
#>  [1] LC_CTYPE=en_US.UTF-8       LC_NUMERIC=C               LC_TIME=en_US.UTF-8        LC_COLLATE=en_US.UTF-8     LC_MONETARY=en_US.UTF-8    LC_MESSAGES=en_US.UTF-8    LC_PAPER=en_US.UTF-8      
#>  [8] LC_NAME=C                  LC_ADDRESS=C               LC_TELEPHONE=C             LC_MEASUREMENT=en_US.UTF-8 LC_IDENTIFICATION=C       
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] BranchRename_0.99.1 colorout_1.2-2     
#> 
#> loaded via a namespace (and not attached):
#>  [1] BiocStyle_2.27.1      jsonlite_1.8.4        compiler_4.3.0        BiocManager_1.30.19   gitcreds_0.1.2        ReleaseLaunch_0.99.10 stringr_1.5.0         credentials_1.3.2    
#>  [9] yaml_2.3.7            fastmap_1.1.0         R6_2.5.1              curl_5.0.0            knitr_1.41            tibble_3.1.8          openssl_2.0.5         pillar_1.8.1         
#> [17] rlang_1.0.6           utf8_1.2.2            stringi_1.7.12        xfun_0.36             sys_3.4.1             cli_3.6.0             magrittr_2.0.3        gh_1.3.1.9000        
#> [25] digest_0.6.31         rstudioapi_0.14       askpass_1.1           gert_1.9.2            lifecycle_1.0.3       vctrs_0.5.2           evaluate_0.20         glue_1.6.2           
#> [33] codetools_0.2-18      rsconnect_0.8.29      fansi_1.0.4           rmarkdown_2.20        httr_1.4.4            tools_4.3.0           pkgconfig_2.0.3       htmltools_0.5.4
```
