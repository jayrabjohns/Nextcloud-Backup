#!/bin/bash

DestDir="./test_dest/"
SrcDir="./test_source/"

#rm -rf "$DestDir"

mkdir -p -- "$DestDir"
mkdir -p -- "$SrcDir"

echo "-----------------------"
echo "Starting backup test..."
echo "-----------------------"

/bin/bash ./nextcloud_backup.sh -d "$DestDir" -s "$SrcDir" -v

echo "---------------------"
echo "Finished backup test."
echo "---------------------"