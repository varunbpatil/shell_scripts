#!/bin/bash
#
# shell script to extract only pointers from eventlog given that
# the pointers are the last field on the line

if [ $# -ne 1 ]; then
    echo "ERROR : one argument : input file name"
    exit 1
fi

# extract only lines that print the pointer
awk '$NF ~ /0x[0-9a-z]*$/ {print $NF}' $1 > pointers

# sort the output file
sort ./pointers > sorted_pointers
rm ./pointers

# find out number of occurences of each uniq pointer value
uniq -c ./sorted_pointers > uniq_pointers
rm sorted_pointers

# print which pointer has odd num of occurances
awk 'BEGIN {count=0} $1%2==1 {print $1, $2; count++} END {printf("\ntotal lost buffers = %d\n", count)}' uniq_pointers
rm uniq_pointers
