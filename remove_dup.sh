#!/bin/bash
#
# shell script to remove duplicate files based on md5sum
# Usage : remove_dup.sh <dir>

dir=$1
if [ ! -d ${dir} ]; then
    echo "could not find dir ${dir}"
    exit 1
fi

echo "deleting duplicates in progress..."
diff <(find ${dir} -type f -print0 | xargs -0 -n1 md5sum | sort | uniq -w32) <(find ${dir} -type f -print0 | xargs -0 -n1 md5sum | sort) | awk -F'  ' '/>/ {print $2}' | tr '\n' '\000' | xargs -I{} -0 -n1 rm -vrf {}
find ${dir} -type d -empty -delete
echo "deleting duplicates done..."

# Explanation:
#
# 1. find . -type f -print0 | xargs -0 -n1 md5sum | sort | uniq -w32
#
# These are basically the files that we would like to keep in the final output directory
#
# 2. find . -type f -print0 | xargs -0 -n1 md5sum | sort
#
# These include the files that we want to keep as well as the duplicate files
#
# So, a diff between the above two will give us the files we need to delete from the directory
#
# 3. awk -F'  ' '/>/ {print $2}'
#
# This extracts only the filenames that need to be removed from the diff output
#
# 4. tr '\n' '\000'
#
# This translates newlines to null characters so that the filenames can be passed to xargs
