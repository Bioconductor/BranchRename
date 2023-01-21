#!/bin/bash
#

#set -e  # exit immediately if a simple command exits with a non-zero status

#GIT_SERVER="git.bioconductor.org"
GIT_SERVER="44.207.152.77"  # testing instance
MASTER_SYMREF="ref: refs/heads/master"
DEVEL_SYMREF="ref: refs/heads/devel"

## --- Check usage ---

print_usage()
{
	cat <<-EOD
	=== flip_git_repo.sh ===
	
	flip_git_repo.sh flips (or unflips) a git repo directly on the git
	server. Use flip_all_git_repos.sh to flip all the git repos located
	in a given directory on the git server.
	
	Note that the script uses ssh to execute commands on the server, so
	the git client is not used or needed.
	
	USAGE:
	
	  to flip:
	    $0 <path/to/repo.git>
	
	  to reverse the flip (i.e. restore repo to its original state):
	    $0 -r <path/to/repo.git>
	
	  to peek only:
	    $0 --peek-only <path/to/repo.git>
	
	  IMPORTANT: <path/to/repo.git> must be the path to a git repo
	  relative to the ~git/repositories/ folder on the git server,
	  e.g. 'packages/Biobase.git' or 'admin/manifest.git'.
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
	if [ "$1" == "--peek-only" ]; then
		action="peek-only"
	else
		action="unflip"
	fi
	path_to_repo="$2"
else
	if [ "$2" != "" ]; then
		print_usage
	fi
	action="flip"
	path_to_repo="$1"
fi

## --- Make sure $path_to_repo refers to a valid git repo ---

echo "git server: $GIT_SERVER"
echo ""

remote_run()
{
	ssh ubuntu@$GIT_SERVER "sudo su - git --command='$1'"
}

repo_rpath="~git/repositories/${path_to_repo}"
HEAD_rpath="$repo_rpath/HEAD"
heads_rpath="$repo_rpath/refs/heads"

remote_run "test -d $repo_rpath"
if [ $? -ne 0 ]; then
	echo "ERROR: $repo_rpath: no such folder on git server"
	echo ""
	print_usage
fi
remote_run "test -f $HEAD_rpath"
if [ $? -ne 0 ]; then
	echo "ERROR: No $HEAD_rpath file"
	echo "  on git server. Is $path_to_repo a valid git repo?"
	exit 1
fi

## --- Take a peek ---

NO_SUCH_FILE="no such file"

get_HEAD()
{
	remote_run "test -f $HEAD_rpath"
	if [ $? -eq 0 ]; then
		remote_run "cat $HEAD_rpath"
	else
		echo "$NO_SUCH_FILE"
	fi
}

get_ref()
{
	remote_run "test -f ${heads_rpath}/$1"
	if [ $? -eq 0 ]; then
		remote_run "cat ${heads_rpath}/$1"
	else
		echo "$NO_SUCH_FILE"
	fi
}

take_peek()
{
	HEAD=`get_HEAD`
	ref_master=`get_ref master`
	ref_devel=`get_ref devel`
	echo "ok"
	echo "  Found in $repo_rpath/:"
	echo "  - file HEAD:               $HEAD"
	echo "  - file refs/heads/master:  $ref_master"
	echo "  - file refs/heads/devel:   $ref_devel"
}

if [ "$action" == "peek-only" ]; then
	echo -n "Taking a peek at repo $path_to_repo on git server ... "
	take_peek
	exit 0
fi

echo -n "Taking a 1st peek at repo $path_to_repo on git server ... "
take_peek
echo ""

flip_repo()
{
	## --- Do nothing if repo is already flipped ---
	if [ "$HEAD" == "$DEVEL_SYMREF" ] && \
	   [ "$ref_master" == "$DEVEL_SYMREF" ]; then
		echo "Repo is already flipped ==> nothing to do."
		exit 2
	fi

	## --- Rename branch 'master' to 'devel' ---
	if [ "$ref_devel" == "$NO_SUCH_FILE" ]; then
		## Branch 'devel' does not exist.
		echo -n "Renaming branch 'master' to 'devel' ... "
		remote_run "mv ${heads_rpath}/master ${heads_rpath}/devel"
		echo "ok"
	fi

	## --- Set default branch to 'devel' ---
	if [ "$HEAD" == "$DEVEL_SYMREF" ]; then
		## Default branch is already set to 'devel'.
		echo -n "Default branch in repo $path_to_repo is already "
		echo "set to 'devel'"
		echo "  ==> no need to touch this."
	else
		## Default branch is NOT set to 'devel'.
		echo -n "Setting default branch to 'devel' ... "
		remote_run "echo \"$DEVEL_SYMREF\" >$HEAD_rpath"
		echo "ok"
	fi

	## --- Create ref 'master' (sym ref to 'devel') ---
	ref_master=`get_ref master`
	if [ "$ref_master" == "$NO_SUCH_FILE" ]; then
		## Ref 'master' does not exist. Create it.
		echo -n "Creating ref 'master' (sym ref to 'devel') ... "
		remote_run "echo \"$DEVEL_SYMREF\" >${heads_rpath}/master"
		echo "ok"
	elif [ "$ref_master" == "$DEVEL_SYMREF" ]; then
		## Ref 'master' exists and is a sym ref to 'devel'.
		echo -n "Repo $path_to_repo already has ref 'master' and ",
		echo "it is a sym ref to 'devel'."
		echo "  ==> no need to create it."
	else
		## Ref 'master' exists but is NOT a sym ref to 'devel'.
		echo -n "WARNING: File refs/heads/master already exists but "
		echo "does NOT contain a sym ref to 'devel'."
		echo "  ==> won't touch it!"
	fi
}

unflip_repo()
{
	## --- Do nothing if repo is in original state ---
	if [ "$HEAD" == "$MASTER_SYMREF" ] && \
	   [ "$ref_devel" == "$NO_SUCH_FILE" ]; then
		echo "Repo is in original state ==> nothing to do."
		exit 2
	fi

	## --- Rename branch 'devel' to 'master' ---
	if [ "$ref_devel" != "$NO_SUCH_FILE" ]; then
		## Branch 'devel' exists.
		echo -n "Renaming branch 'devel' to 'master' ... "
		remote_run "mv ${heads_rpath}/devel ${heads_rpath}/master"
		echo "ok"
	fi

	## --- Set default branch to 'master' ---
	if [ "$HEAD" == "$MASTER_SYMREF" ]; then
		## Default branch is already set to 'master'.
		echo -n "Default branch in repo $path_to_repo is already "
		echo "set to 'master'"
		echo "  ==> no need to touch this."
	else
		## Default branch is NOT set to 'master'.
		echo -n "Setting back default branch to 'master' ... "
		remote_run "echo \"$MASTER_SYMREF\" >$HEAD_rpath"
		echo "ok"
	fi
}

if [ "$action" == "flip" ]; then
	flip_repo
else
	unflip_repo
fi

echo ""
echo -n "Taking a 2nd peek at repo $path_to_repo on git server ... "
take_peek

echo ""
echo "Repo $path_to_repo sucesfully ${action}ped."

exit 0
