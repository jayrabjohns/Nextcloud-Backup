#!/bin/bash

# Backup solution based on https://kevq.uk/how-to-backup-nextcloud/
# Argument passing based on https://tecadmin.net/pass-command-line-arguments-in-shell-script/

currentDateTime=$(date +"%Y-%m-%d_%H-%M-%S")
dataSourceDir=""    # /mnt/cloud/data/
backupParentDir=""  # /mnt/backups/nextcloud/
logsDir=""
verbose=false

printUsage() 
{
    echo "  -h  shows this help message"
    echo "  -s  directory for data to backup"
    echo "  -d  directory for backup storage"
    echo "  -v  increases verbosity"
}

# log()
# {
#     if [ "$verbose" = true ]; then
#         echo "$1"
#         echo "Verbose!"
#     fi

#     echo "$1" >> "$logsDir""$currentDateTime.log"
# }

runBackup()
{
    dataDir="$backupParentDir""data/"
    databaseDir="$backupParentDir""database/"
    oldDataDestinationDir="$backupParentDir""old/"

    # Creating directories if needed
    if [ ! -d "$dataDir" ]; then
        mkdir "$dataDir"
    fi
    if [ ! -d "$databaseDir" ]; then
        mkdir "$databaseDir"
    fi
    if [ ! -d "$oldDataDestinationDir" ]; then
        mkdir "$oldDataDestinationDir"
    fi

    # Creating backup metadata file
    echo "date: ${currentDateTime}" > "$backupParentDir""backup_metadata"

    # Compressing old backup, if data exists
    if [ -z "$(ls -A $dataDir)" ]; then
        echo "$dataDir is empty, skipping compression of old backup";
    else
        echo "--Compressing old backup...--"
        tar -zcf "${oldDataDestinationDir}${currentDateTime}.tar.gz" "${dataDir}" "${databaseDir}" "${logsDir}"
    fi

    # Backup data
    echo "--Starting data backup...--"
    nextcloud.occ maintenance:mode --on
    rsync -Aavx "${dataSourceDir}" "${dataDir}"
    nextcloud.occ maintenance:mode --off
    echo "--Data backup finished--"

    # Export apps, database, config
    echo "--Starting export of apps, database, and config...--" 
    nextcloud.export -abc
    echo "--Completed export of apps, database, and config--"

    # Compress export
    echo "--Compressing export...--"
    tar -zcf "${databaseDir}${currentDateTime}.tar.gz" /var/snap/nextcloud/common/backups/*
    echo "--Export compressed to ${databaseDir}--"

    # Remove uncompressed export
    rm -rf /var/snap/nextcloud/common/backups/*

    # Remove old backups older than 14 days
    echo "--Removing backups older than 14 days...--"
    find "${oldDataDestinationDir}" -mtime +14 -type f -delete
    echo "--Old backups removed--"

    echo "--Nextcloud backup completed successfully.--"
}


######      Main      ######

# Check if user is sudo or root
if [ "$(whoami)" != root ]; then
    echo "You need to be root or use sudo to run this."
    exit;
fi

# Parameter selection
while getopts ":hvs:d:" option; do
    case $option in
        h) # Display help
            printUsage
            exit;;
        v) # Increases verbosity
            verbose=true;;
        s) #Defines source directory
            dataSourceDir="$OPTARG";;
        d) #Defines destination directory
            backupParentDir="$OPTARG";;
        \?) # Invalid option
            echo "Error: Invalid option"
            exit;;
    esac
done

# Parameter validation
if [[ ! -d "$dataSourceDir" || ! "$dataSourceDir" == */ ]]; then
    echo "Provide a valid source directory. (Be sure to include a slash at the end)"
    exit;
elif [[ "$backupParentDir" = "" || ! "$backupParentDir" == */ ]]; then
    echo "Provide a destination directory. (Be sure to include a slash at the end)"
    exit;
fi

logsDir=$backupParentDir"logs/"

# Creating necessary directories if needed
if [ ! -d "$backupParentDir" ]; then
    mkdir "$backupParentDir"
fi
if [ ! -d "$logsDir" ]; then
    mkdir "$logsDir"
fi

# Printing to log file and or stdout
if [ "$verbose" = true ]; then
    runBackup | tee "$logsDir""$currentDateTime.log"
else
    runBackup > "$logsDir""$currentDateTime.log"
fi
