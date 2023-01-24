#!/bin/bash
#

#set -e  # exit immediately if a simple command exits with a non-zero status

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
	
	The script is meant to be run directly on the Bioconductor git
	server, from the ubuntu account.
	
	USAGE:
	
	  to flip:
	    $0 <path/to/repo.git>
	
	  to reverse the flip (i.e. restore the repo to its original state
	  a.k.a. unflip the repo):
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

run_as_git_user()
{
	sudo su - git --command="$1"
}

repo_rpath="~git/repositories/${path_to_repo}"
heads_rpath="$repo_rpath/refs/heads"
HEAD_rpath="$repo_rpath/HEAD"

run_as_git_user "test -d $repo_rpath"
if [ $? -ne 0 ]; then
	echo "ERROR: $repo_rpath: no such folder on server"
	echo ""
	print_usage
fi
run_as_git_user "test -d $heads_rpath"
if [ $? -ne 0 ]; then
	echo "ERROR: No $heads_rpath folder on server"
	echo "  Is $path_to_repo a valid git repo?"
	exit 1
fi
run_as_git_user "test -f $HEAD_rpath"
if [ $? -ne 0 ]; then
	echo "ERROR: No $HEAD_rpath file on server"
	echo "  Is $path_to_repo a valid git repo?"
	exit 1
fi

## --- Take a peek ---

NO_SUCH_FILE="no such file"

get_ref()
{
	run_as_git_user "test -f ${heads_rpath}/$1"
	if [ $? -eq 0 ]; then
		run_as_git_user "cat ${heads_rpath}/$1"
	else
		echo "$NO_SUCH_FILE"
	fi
}

get_HEAD()
{
	run_as_git_user "test -f $HEAD_rpath"
	if [ $? -eq 0 ]; then
		run_as_git_user "cat $HEAD_rpath"
	else
		echo "$NO_SUCH_FILE"
	fi
}

take_peek()
{
	ref_master=`get_ref master`
	ref_devel=`get_ref devel`
	HEAD=`get_HEAD`
	echo "ok"
	echo "  Found in $repo_rpath/:"
	echo "  - file refs/heads/master:  $ref_master"
	echo "  - file refs/heads/devel:   $ref_devel"
	echo "  - file HEAD:               $HEAD"
}

if [ "$action" == "peek-only" ]; then
	echo -n "Taking a peek at repo $path_to_repo ... "
	take_peek
	exit 0
fi

echo -n "Taking a 1st peek at repo $path_to_repo ... "
take_peek
echo ""

flip_repo()
{
	## --- Do nothing if repo is already flipped ---
	if [ "$ref_master" == "$DEVEL_SYMREF" ] && \
	   [ "$ref_devel" != "$NO_SUCH_FILE" ] && \
	   [ "$HEAD" == "$DEVEL_SYMREF" ]; then
		echo "Repo is already flipped ==> nothing to do."
		exit 2
	fi

	## --- Rename branch 'master' to 'devel' ---
	if [ "$ref_devel" == "$NO_SUCH_FILE" ]; then
		## Branch 'devel' does not exist.
		echo -n "Renaming branch 'master' to 'devel' ... "
		run_as_git_user "mv ${heads_rpath}/master ${heads_rpath}/devel"
		echo "ok"
	fi

	## --- Create ref 'master' (sym ref to 'devel') ---
	ref_master=`get_ref master`
	if [ "$ref_master" == "$NO_SUCH_FILE" ]; then
		## Ref 'master' does not exist. Create it.
		echo -n "Creating ref 'master' (sym ref to 'devel') ... "
		run_as_git_user "echo \"$DEVEL_SYMREF\" >${heads_rpath}/master"
		echo "ok"
	elif [ "$ref_master" == "$DEVEL_SYMREF" ]; then
		## Ref 'master' exists and is a sym ref to 'devel'.
		echo -n "Repo $path_to_repo already has ref 'master' and ",
		echo "it is a sym ref to 'devel'."
		echo "  ==> no need to create it."
	else
		## Ref 'master' exists but is NOT a sym ref to 'devel'.
		echo -n "ERROR: File refs/heads/master already exists but "
		echo "does NOT contain a sym ref to 'devel'."
		exit 1
	fi

	## --- Switch default branch from 'master' to 'devel' ---
	if [ "$HEAD" == "$MASTER_SYMREF" ]; then
		echo -n "Switching default branch from 'master' to 'devel' ... "
		run_as_git_user "echo \"$DEVEL_SYMREF\" >$HEAD_rpath"
		echo "ok"
	elif [ "$HEAD" == "$DEVEL_SYMREF" ]; then
		## Default branch is already set to 'devel'.
		echo -n "Default branch in repo $path_to_repo is already "
		echo "set to 'devel'"
		echo "  ==> no need to touch this."
	else
		## Default branch is neither 'master' or 'devel'.
		echo -n "ERROR: Default branch is neither 'master' "
		echo "or 'devel' ... "
		exit 1
	fi
}

unflip_repo()
{
	## --- Do nothing if repo is in original state ---
	if [ "$ref_master" != "$NO_SUCH_FILE" ] && \
	   [ "$ref_devel" == "$NO_SUCH_FILE" ] && \
	   [ "$HEAD" == "$MASTER_SYMREF" ]; then
		echo "Repo is in original state ==> nothing to do."
		exit 2
	fi

	## --- Switch default branch from 'devel' to 'master' ---
	if [ "$HEAD" == "$DEVEL_SYMREF" ]; then
		echo -n "Switching default branch from 'devel' to 'master' ... "
		run_as_git_user "echo \"$MASTER_SYMREF\" >$HEAD_rpath"
		echo "ok"
	elif [ "$HEAD" == "$MASTER_SYMREF" ]; then
		## Default branch is already set to 'master'.
		echo -n "Default branch in repo $path_to_repo is already "
		echo "set to 'master'"
		echo "  ==> no need to touch this."
	else
		## Default branch is neither 'master' or 'devel'.
		echo -n "ERROR: Default branch is neither 'master' "
		echo "or 'devel' ... "
		exit 1
	fi

	## --- Rename branch 'devel' to 'master' ---
	## This will destroy ref 'master' if it exists.
	if [ "$ref_devel" != "$NO_SUCH_FILE" ]; then
		## Branch 'devel' exists.
		echo -n "Renaming branch 'devel' to 'master' ... "
		run_as_git_user "mv ${heads_rpath}/devel ${heads_rpath}/master"
		echo "ok"
	fi
}

if [ "$action" == "flip" ]; then
	flip_repo
else
	unflip_repo
fi

echo ""
echo -n "Taking a 2nd peek at repo $path_to_repo ... "
take_peek

echo ""
echo "Repo $path_to_repo sucesfully ${action}ped."

exit 0
