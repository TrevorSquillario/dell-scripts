#!/bin/bash
while getopts u:p:f: flag
do
    case "${flag}" in
        u) username=${OPTARG};;
        p) password=${OPTARG};;
        f) filename=${OPTARG};;
    esac
done

cat $filename | while read line || [[ -n $line ]];
do
    echo "Connecting to $line"
    racadm --nocertwarn -r $line -u $username -p "$password"  get System.ServerTopology
done