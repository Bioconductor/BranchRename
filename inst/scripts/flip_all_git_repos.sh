#!/bin/bash
#

#set -e  # exit immediately if a simple command exits with a non-zero status

#GIT_SERVER="git.bioconductor.org"
GIT_SERVER="44.207.152.77"  # testing instance
FLIP_GIT_REPO_SCRIPT_NAME="flip_git_repo.sh"

## --- Check usage ---

print_usage()
{
	cat <<-EOD
	=== flip_all_git_repos.sh ===
	
	flip_all_git_repos.sh calls $FLIP_GIT_REPO_SCRIPT_NAME in a loop
	to flip all the git repos located in a given directory
	on the git server.
	
	USAGE:
	
	  to flip all the git repos in a directory:
	    $0 <path/to/dir>
	
	  to reverse the flip for all the git repos in a directory (i.e.
	  restore repos to their original state):
	    $0 -r <path/to/dir>
	
	  to peek only:
	    $0 --peek-only <path/to/dir>
	
	  IMPORTANT: <path/to/dir> must be the path to a directory relative
	  to the ~git/repositories/ folder on the git server, e.g. 'packages'
	  or 'admin'.
	
	Example: To restore all the git repos in ~git/repositories/packages/
	(3111 repos as of 2023/01/21) to their original state (and redirect
	the script output to restore.log):
	
	    # Takes about 8 hours to process the 3111 repos!
	    time $0 -r packages >>restore.log 2>&1 &
	    tail -f restore.log  # watch progress
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

## --- Locate flip_git_repo.sh script ---

flip_git_repo_script="`dirname $0`/$FLIP_GIT_REPO_SCRIPT_NAME"
test -f $flip_git_repo_script
if [ $? -ne 0 ]; then
	flip_git_repo_script=`which "$FLIP_GIT_REPO_SCRIPT_NAME"`
	if [ $? -ne 0 ]; then
		echo "ERROR: $FLIP_GIT_REPO_SCRIPT_NAME script not found"
	fi
fi

echo "- $FLIP_GIT_REPO_SCRIPT_NAME script: $flip_git_repo_script"

## --- Make sure $path_to_dir refers to an existing directory ---

echo "- git server: $GIT_SERVER"

remote_run()
{
	ssh ubuntu@$GIT_SERVER "sudo su - git --command='$1'"
}

dir_rpath="~git/repositories/${path_to_dir}"

remote_run "test -d $dir_rpath"
if [ $? -ne 0 ]; then
	echo "ERROR: $dir_rpath: no such folder on git server"
	echo ""
	print_usage
fi

all_repos=`remote_run "cd $dir_rpath && ls -d *.git"`
num_repos=`echo "$all_repos" | wc -w`
echo "- number of git repos found on server in $dir_rpath/: $num_repos"
echo ""

counter="0"
for repo in $all_repos; do
	(( counter=$counter+1 ))
	echo "----------------------------------------------------------------"
	path_to_repo="$path_to_dir/$repo"
	echo "PROCESSING REPO $path_to_repo ($counter/$num_repos)"
	$flip_git_repo_script "$1" "$path_to_repo"
	if [ $? -eq 1 ]; then
		exit 1
	fi
	echo ""
done
echo "----------------------------------------------------------------"

echo ""
echo "DONE."

exit 0
