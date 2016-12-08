#!/bin/bash

LPS="LPS-57985"

#for the first backport
FROMBRANCH=ee-7.0.x
#for subsequent backports use your previous backport branch
#FROMBRANCH=ee-7.0.x-$LPS
TOBRANCH=ee-6.2.x

BACKPORTBRANCH="${TOBRANCH}-${LPS}"

COMMITS="commits-${LPS}.txt"
FILENAMES="filenames-${LPS}.txt"
REPLACENAMES="replacenames-${LPS}.txt"

ACTUALBRANCH=`git branch | grep \* | cut -d ' ' -f2`

function refreshBranches {
	for branch in $FROMBRANCH $TOBRANCH; do
		# dont try to refresh local-only branches
		if echo -n $branch|grep 'LPS'; then
			continue;
		fi;

		echo -e "\n\nRefreshing branch $branch\n"

		if [ "$branch" == "$ACTUALBRANCH" ]; then
			git pull upstream $branch
		else 
			git fetch --no-tags upstream ${branch}:${branch}
		fi
	done
}

#refreshBranches

echo -e "\n\nGetting the hashes of the commits\n"

git log $FROMBRANCH --reverse --pretty=format:'%H' --grep "$LPS" > "$COMMITS"
cat $COMMITS

echo -e "\n\nGetting the file names for the commits\n"

for i in `cat "${COMMITS}"`; do  git show --pretty="" --name-only $i; done|sort|uniq > "${FILENAMES}"
#The sort|uniq at the end will delete all the repeated file names.
cat $FILENAMES

#Now we can check how the file names changed:
echo -n > "${REPLACENAMES}"

echo -e "\n\nGetting the file name changes\n"

for i in `cat "${FILENAMES}"`; do
 echo -n "s@${i}@" >> "${REPLACENAMES}"
 oldName=`git log $FROMBRANCH --pretty="" --name-only --follow  ${FROMBRANCH}...${TOBRANCH} -- $i|tail -1`
 echo "${i} <=== $oldName"
 echo -n $oldName|sed -e 's/$/@g/' >> "${REPLACENAMES}"
 echo >> "${REPLACENAMES}"
done

echo -e "\n\nCreating and checking out backport branch\n"

if git branch|grep "$BACKPORTBRANCH"; then
	echo "WARNING: $BACKPORTBRANCH exists. Check before commiting"
	git checkout $BACKPORTBRANCH
else
	git checkout -b "$BACKPORTBRANCH" "${TOBRANCH}"
fi

echo -e "\n\nRun these commands in this order to generate and apply patches:\n"

for commit in `cat "$COMMITS"`; do
	echo "git format-patch -1 --stdout ${commit}|sed -f ${REPLACENAMES}|git apply --verbose --3way -"
done
