#!/bin/bash
#
# shell script to automatically perform union of two directories
# and copy the union to both pc's
# union.sh <ip_addr_of_pc_1> <dir_of_pc_1> <ip_addr_of_pc_2> <dir_of_pc_2>

if [ $# -ne 4 ]; then
    echo "wrong usage"
    echo "union.sh <ip_addr_of_pc_1> <dir_of_pc_1> <ip_addr_of_pc_2> <dir_of_pc_2>"
    exit 1
else
    pc1=$1
    dir1=$2
    pc2=$3
    dir2=$4
fi

# get ip_addr of pc on which this script is running
current_ip=`ifconfig eth0 | awk '/inet addr/ {print $2}' | awk -F: '{print $2}'`

# sanity checks
if [ "${current_ip}" == "${pc1}" ]; then
    ping -c 1 -t 10 ${pc2} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "failed to connect to ${pc2}"
        exit 1
    fi
else
    ping -c 1 -t 10 ${pc1} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "failed to connect to ${pc1}"
        exit 1
    fi
fi
if [ "${current_ip}" == "${pc1}" ]; then
    if [ ! -d ${dir1} ]; then
        echo "cannot find dir ${dir1} on ${pc1}"
        exit 1
    fi
    ssh varun@${pc2} "ls ${dir2}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "cannot find dir ${dir2} on ${pc2}"
    fi
else
    if [ ! -d ${dir2} ]; then
        echo "cannot find dir ${dir2} on ${pc2}"
        exit 1
    fi
    ssh varun@${pc1} "ls ${dir1}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "cannot find dir ${dir1} on ${pc1}"
    fi
fi
echo "sanity checks complete..."

echo "sync in progress..."
if [ "${current_ip}" == "${pc1}" ]; then
    rsync -avze ssh --ignore-existing ${dir1}/* varun@${pc2}:${dir2}/ > /dev/null 2>&1
    rsync -avze ssh --ignore-existing varun@${pc2}:${dir2}/* ${dir1}/ > /dev/null 2>&1
else
    rsync -avze ssh --ignore-existing ${dir2}/* varun@${pc1}:${dir1}/ > /dev/null 2>&1
    rsync -avze ssh --ignore-existing varun@${pc1}:${dir1}/* ${dir2}/ > /dev/null 2>&1
fi
echo "sync completed..."
