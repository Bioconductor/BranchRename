#!/bin/bash
#

#set -e  # exit immediately if a simple command exits with a non-zero status

MASTER_SYMREF="ref: refs/heads/master"
DEVEL_SYMREF="ref: refs/heads/devel"

## --- Check usage ---

print_usage()
{
	cat <<-EOD
	=== flip_repo.sh ===
	
	flip_repo.sh flips (or unflips) a git repo directly on the
	Bioconductor git server. Use flip_all_repos.sh to flip all
	the git repos located in a given directory on the server.
	
	The script is meant to be run directly on the Bioconductor git
	server, from the git account.
	
	USAGE:
	
	  to flip a repo:
	    $0 <path/to/repo.git>
	
	  to reverse the flip (i.e. restore the repo to its original state
	  a.k.a. unflip the repo):
	    $0 -r <path/to/repo.git>
	
	  to peek only:
	    $0 --peek-only <path/to/repo.git>
	
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

## --- Make sure that $path_to_repo refers to a valid git repo ---

path_to_heads="$path_to_repo/refs/heads"
path_to_HEAD="$path_to_repo/HEAD"

test -d "$path_to_repo"
if [ $? -ne 0 ]; then
	echo "ERROR: $path_to_repo/: folder not found."
	echo ""
	print_usage
fi
test -d "$path_to_heads"
if [ $? -ne 0 ]; then
	echo "ERROR: $path_to_heads/: folder not found."
	echo "  Is $path_to_repo a valid git repo?"
	echo ""
	print_usage
fi
branches=`ls -A "$path_to_heads"`
if [ -z "$branches" ]; then
	echo -n "Repo $path_to_repo is empty (refs/heads/ is empty) "
	echo "==> don't touch it."
	exit 2
fi
test -f "$path_to_HEAD"
if [ $? -ne 0 ]; then
	echo "ERROR: $path_to_HEAD/: file not found."
	echo "  Is $path_to_repo a valid git repo?"
	echo ""
	print_usage
fi

## --- Take a peek ---

NO_SUCH_FILE="no such file"

get_ref()
{
	test -f "${path_to_heads}/$1"
	if [ $? -eq 0 ]; then
		cat "${path_to_heads}/$1"
	else
		echo "$NO_SUCH_FILE"
	fi
}

get_HEAD()
{
	test -f "$path_to_HEAD"
	if [ $? -eq 0 ]; then
		cat "$path_to_HEAD"
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
	echo "--> Found in $path_to_repo/:"
	echo "    - file refs/heads/master:  $ref_master"
	echo "    - file refs/heads/devel:   $ref_devel"
	echo "    - file HEAD:               $HEAD"
	echo ""
	if [ "$ref_devel" == "$NO_SUCH_FILE" ]; then
		## Repo has no 'devel' branch.
		if [ "$ref_master" == "$NO_SUCH_FILE" ]; then
			echo -n "ERROR: Repo $path_to_repo has no 'master' "
			echo "or 'devel' branch!"
			exit 1
		fi
		if [ "$ref_master" == "$DEVEL_SYMREF" ]; then
			echo -n "ERROR: Repo $path_to_repo has a 'master' "
			echo "branch that is a sym ref "
			echo -n "  to its 'devel' branch, but the latter "
			echo "does not exist!"
			exit 1
		fi
		if [ "$HEAD" != "$MASTER_SYMREF" ]; then
			echo -n "ERROR: Repo $path_to_repo has a "
			echo "'master' branch and no 'devel' branch."
			echo -n "  So its default branch is expected "
			echo "to be 'master', but it's not!"
			exit 1
		fi
		## Repo is in original state.
		repo_state="0"
	else
		## Repo does have a 'devel' branch.
		if [ "$ref_master" == "$NO_SUCH_FILE" ]; then
			## Repo has no 'master' branch.
			if [ "$HEAD" != "$DEVEL_SYMREF" ]; then
				echo -n "ERROR: Repo $path_to_repo has a "
				echo "'devel' branch and no 'master' branch."
				echo -n "  So its default branch is expected "
				echo "to be 'devel', but it's not!"
				exit 1
			fi
			## Repo has a 'devel' branch but no 'master' sym ref.
			repo_state="1"
		else
			## Repo does have a 'master' branch.
			if [ "$ref_master" != "$DEVEL_SYMREF" ]; then
				echo -n "ERROR: Repo $path_to_repo has "
				echo "branches 'master' and 'devel'"
				echo -n "  but the former is not "
				echo "a sym ref to the latter!"
				exit 1
			fi
			if [ "$HEAD" == "$MASTER_SYMREF" ]; then
				## Repo has a 'devel' branch and the 'master'
				## sym ref but default branch is still 'master'.
				repo_state="2"
			elif [ "$HEAD" == "$DEVEL_SYMREF" ]; then
				## Repo is fully flipped.
				repo_state="3"
			else
				echo -n "ERROR: Repo $path_to_repo has "
				echo "branches 'master' and 'devel'."
				echo -n "  So its default branch is expected "
				echo "be one or the other, but it's not!"
				exit 1
			fi
		fi
	fi
}

if [ "$action" == "peek-only" ]; then
	echo -n "Taking a peek at $path_to_repo ... "
	take_peek
	exit 0
fi

echo -n "Taking a 1st peek at $path_to_repo ... "
take_peek

flip_repo()
{
	## --- Do nothing if repo is already flipped ---
	if [ "$repo_state" == "3" ]; then
		echo "Repo is already flipped ==> nothing to do."
		exit 3
	fi

	## --- Rename branch 'master' to 'devel' ---
	if [ "$repo_state" == "0" ]; then
		echo -n "Renaming branch 'master' to 'devel' ... "
		mv "${path_to_heads}/master" "${path_to_heads}/devel"
		echo "ok"
	fi

	## --- Create ref 'master' (sym ref to 'devel') ---
	if [ "$repo_state" == "0" ] || [ "$repo_state" == "1" ]; then
		echo -n "Creating ref 'master' (sym ref to 'devel') ... "
		echo "$DEVEL_SYMREF" >"${path_to_heads}/master"
		echo "ok"
	else
		## "$repo_state" == "2"
		echo -n "Repo $path_to_repo already has ref 'master' "
		echo "and it's a sym ref"
		echo "to 'devel' ==> no need to create it."
	fi

	## --- Switch default branch from 'master' to 'devel' ---
	if [ "$repo_state" == "0" ] || [ "$repo_state" == "2" ]; then
		echo -n "Switching default branch from 'master' to 'devel' ... "
		echo "$DEVEL_SYMREF" >"$path_to_HEAD"
		echo "ok"
	else
		## "$repo_state" == "1"
		echo -n "Default branch in repo $path_to_repo is already "
		echo "set to 'devel'"
		echo "  ==> no need to touch this."
	fi
}

unflip_repo()
{
	## --- Do nothing if repo is in original state ---
	if [ "$repo_state" == "0" ]; then
		echo "Repo is in original state ==> nothing to do."
		exit 3
	fi

	## --- Rename branch 'devel' to 'master' ---
	echo -n "Renaming branch 'devel' to 'master' ... "
	mv "${path_to_heads}/devel" "${path_to_heads}/master"
	echo "ok"

	## --- Switch default branch from 'devel' to 'master' ---
	if [ "$repo_state" == "3" ] || [ "$repo_state" == "1" ]; then
		echo -n "Switching default branch from 'devel' to 'master' ... "
		echo "$MASTER_SYMREF" >"$path_to_HEAD"
		echo "ok"
	else
		## "$repo_state" == "2"
		echo -n "Default branch in repo $path_to_repo is already "
		echo "set to 'master'"
		echo "  ==> no need to touch this."
	fi
}

if [ "$action" == "flip" ]; then
	flip_repo
else
	unflip_repo
fi

echo ""
echo -n "Taking a 2nd peek at $path_to_repo ... "
take_peek

echo "Repo $path_to_repo successfully ${action}ped."

exit 0
