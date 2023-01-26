#!/bin/bash
#

#set -e  # exit immediately if a simple command exits with a non-zero status

FLIP_REPO_SCRIPT_NAME="flip_repo.sh"

## --- Check usage ---

print_usage()
{
	cat <<-EOD
	=== flip_all_repos.sh ===
	
	flip_all_repos.sh calls $FLIP_REPO_SCRIPT_NAME in a loop to flip all
	the git repos located in a given directory on the Bioconductor
	git server.
	
	The script is meant to be run directly on the Bioconductor git
	server, from the git account.
	
	USAGE:
	
	  to flip all the git repos in a directory:
	    $0 <path/to/dir>
	
	  to reverse the flip for all the git repos in a directory (i.e.
	  restore the repos to their original state a.k.a. unflip the repos):
	    $0 -r <path/to/dir>
	
	  to peek only:
	    $0 --peek-only <path/to/dir>
	
	EXAMPLES:
	
	- Take a peek at all the git repos in ~git/repositories/packages/
	  (3111 repos as of 2023/01/21 on the testing instance), and redirect
	  the script output to peek.log:
	
	    # Takes about 7 min to complete.
	    time $0 --peek-only ~git/repositories/packages >peek.log 2>&1 &
	    tail -f peek.log  # watch progress
	
	- Flip all the git repos in ~git/repositories/packages/ and redirect
	  the script output to flip.log:

	    # Takes about 13 min to complete.	
	    time $0 ~git/repositories/packages >flip.log 2>&1 &
	    tail -f flip.log  # watch progress
	
	- Restore all the git repos in ~git/repositories/packages/ to their
	  original state, and redirect the script output to unflip.log:
	
	    # Takes about 12 min to complete.
	    time $0 -r ~git/repositories/packages >unflip.log 2>&1 &
	    tail -f unflip.log  # watch progress
	
	For questions or help: Hervé Pagès <hpages.on.github@gmail.com>	
	EOD
	exit 1
}

if [ "$1" == "" ]; then
	print_usage
fi

if [ "$1" == "--peek-only" ] || [ "$1" == "-r" ]; then
	if [ "$2" == "--peek-only" ] || [ "$2" == "-r" ] || \
	   [ "$2" == "" ] || [ "$3" != "" ]; then
		print_usage
	fi
	path_to_dir="$2"
else
	if [ "$2" != "" ]; then
		print_usage
	fi
	path_to_dir="$1"
fi

## --- Locate flip_repo.sh script ---

flip_repo_script="`dirname $0`/$FLIP_REPO_SCRIPT_NAME"
test -f $flip_repo_script
if [ $? -ne 0 ]; then
	flip_repo_script=`which "$FLIP_REPO_SCRIPT_NAME"`
	if [ $? -ne 0 ]; then
		echo "ERROR: $FLIP_REPO_SCRIPT_NAME script not found"
		exit 1
	fi
fi

echo "- $FLIP_REPO_SCRIPT_NAME script: $flip_repo_script"

## --- Make sure $path_to_dir refers to an existing directory ---

test -d "$path_to_dir"
if [ $? -ne 0 ]; then
	echo "ERROR: $path_to_dir: folder not found."
	echo ""
	print_usage
fi

all_repos=`cd "$path_to_dir" && ls -d *.git`
num_repos=`echo "$all_repos" | wc -w`
echo "- number of git repos found in $path_to_dir/: $num_repos"
echo ""

counter="0"
for repo in $all_repos; do
	(( counter=$counter+1 ))
	echo "----------------------------------------------------------------"
	path_to_repo="$path_to_dir/$repo"
	echo "PROCESSING REPO $path_to_repo ($counter/$num_repos)"
	echo ""

	## Hardcoded list of repos to skip.
	if [ "$repo" == "phastCons30way.UCSC.hg38.git" ] || \
	   [ "$repo" == "UCSCRepeatMasker.git" ]; then
		echo -n "Repo $path_to_repo is in a weird state "
		echo "(no ref 'master') ==> skip it!"
		continue
	fi

	if [ "$2" == "" ]; then
		$flip_repo_script "$path_to_repo"
	else
		$flip_repo_script "$1" "$path_to_repo"
	fi
	if [ $? -eq 1 ]; then
		exit 1
	fi
	echo ""
done
echo "----------------------------------------------------------------"

echo ""
echo "DONE."

exit 0
