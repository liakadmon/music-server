#!/bin/bash

#if [[ ! -z "$2" ]]; then
    t="$@"
#    d=${t//\\//}
#    p=${t//\\//}
#    d=$(echo "$p" | jq -r .localDirectoryName)
remove="\/app\/downloads\/" # change this based on your local download directory
name=$(echo "$@" | sed "s/$remove\(.*\)/\1/" | tr -d '"' )
musicdir="[DOWNLOADS DIRECTORY HERE]"
musicdir+=$name
chown -R [YOUR USERNAME] "$musicdir"
beet import -q "$musicdir"
#echo "$name"
