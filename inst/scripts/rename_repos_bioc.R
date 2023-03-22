library(BranchRename)
dir.create("~/tmp")
setwd("~/tmp")

# Bioconductor package repo rename default to devel -----------------------
ghrepos <- packages_with_default_branch()
rename_branch_packages(ghrepos)

# Bioconductor repos default branch rename --------------------------------
biocrepos <- repos_with_default_branch(branches = "master")
length(biocrepos)
## 181 repositories (rename all?)
sort(names(biocrepos))

.EXCLUDED <- c(
    "bioconductor_docker", "support.bioconductor.org", "issue_tracker_github",
    "packagebuilder", "bioc-common-python", "BioconductorAnnotationPipeline",
    "YouTube", "GitContribution", "git_credentials", "SCExploration"
)
## exclude Bioc2023 repos and bioc_docker support.bioc.org
excludeCurrentBIOC <- grepl("BioC2023", names(biocrepos), ignore.case = TRUE) |
    names(biocrepos) %in% .EXCLUDED |
    grepl("spb", names(biocrepos), ignore.case = TRUE) |
    grepl("Hub", names(biocrepos), ignore.case = FALSE)

excluded <- biocrepos[excludeCurrentBIOC]
sort(names(excluded))
dput(sort(names(excluded)))
#' c("AnnotationHub_docker", "AnnotationHubServer3.0", "bioc-common-python", 
#'   "BioC2023", "BiocHubServer", "bioconductor_docker", "BioconductorAnnotationPipeline", 
#'   "EuroBioC2023", "ExperimentHub_docker", "HubGrub", "HubLogs", 
#'   "HubServer", "issue_tracker_github", "packagebuilder", "spb_history", 
#'   "spb-properties", "spbtest3", "spbtest4", "spbtest5", "support.bioconductor.org"
#' )

# Final list of repositories to rename ------------------------------------
valid_bioc <- biocrepos[!excludeCurrentBIOC]
sort(names(valid_bioc))
rename_branch_repos(valid_bioc, org = "Bioconductor")

