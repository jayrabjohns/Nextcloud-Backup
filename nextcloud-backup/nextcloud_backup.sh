#!/bin/bash

# Backup solution based on https://kevq.uk/how-to-backup-nextcloud/
# Argument passing based on https://tecadmin.net/pass-command-line-arguments-in-shell-script/

CurrentDateTime=$(date +"%Y-%m-%d_%H-%M-%S")
DataSourceDir=""    # /mnt/cloud/data/
BackupParentDir=""  # /mnt/backups/nextcloud/
LogsDir=""
Verbose="false"

PrintUsage() 
{
    printf 
    "-h --help      shows this help message" +
    "-s --src       directory for data to backup\n" + 
    "-d --dest      directory for backup storage\n" +
    "-v --verbose   increases verbosity\n"
}

Log()
{
    if [ "$Verbose" = "true" ]; then
        echo "$1"
    fi

    echo "$1" >> "$LogsDir""$CurrentDateTime"
}

RunBackup()
{
    dataDir="$BackupParentDir""data/"
    databaseDir="$BackupParentDir""database/"
    oldDataDestinationDir="$BackupParentDir""old/"

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
    echo "date: ${CurrentDateTime}" > "$BackupParentDir""backup_metadata"

    # Output to a logfile
    # exec &> "$LogsDir$CurrentDateTime.txt"

    # Compressing old backup, if data exists
    if find -- "$dataDir" -prune -type d -empty | grep -q '^'; then
    Log "$dataDir is empty, skipping compression of old backup";
    else
    Log "Compressing old backup..."
    tar -zcf "${oldDataDestinationDir}${CurrentDateTime}.tar.gz" "${dataDir}" "${databaseDir}" "${LogsDir}"
    fi

    # Backup data
    Log "Starting data backup..."
    nextcloud.occ maintenance:mode --on
    rsync -Aavx "${DataSourceDir}" "${dataDir}"
    nextcloud.occ maintenance:mode --off
    Log "Data backup finished"

    # Export apps, database, config
    Log "Starting export of apps, database, and config..." 
    nextcloud.export -abc
    Log "Export complete"

    # Compress export
    Log "Compressing export..."
    tar -zcf "${databaseDir}${CurrentDateTime}.tar.gz" /var/snap/nextcloud/common/backups/*
    Log "Export successfully compressed to ${databaseDir}"

    # Remove uncompressed export
    rm -rf /var/snap/nextcloud/common/backups/*

    # Remove old backups older than 14 days
    Log "Removing backups older than 14 days..."
    find "${oldDataDestinationDir}" -mtime +14 -type f -delete
    Log "Old backups succefully removed"

    Log "Nextcloud backup completed successfully."
}


######      Main      ######
ARGS=$(getopt -a --options s:d:vh --long "src:,dest:,verbose,help" -- "$@")
eval set -- "$ARGS"

# Parameter selection
while true; do
    case "$1" in
        -s|--src)
        DataSourceDir="$2"
        shift 2;;
        -d|--dest)
        BackupParentDir="$2"
        shift 2;;
        -v|--verbose)
        Verbose="true"
        shift 2;;
        -h|--help)
        PrintUsage
        shift 2;;
        --)
        break;;
    esac
done

# Parameter validation
if [ ! -d "$DataSourceDir" ]; then 
    echo "Provide a valid source directory."
elif [ "$BackupParentDir" = "" ]; then
    echo "Provide a destination directory"
else
    LogsDir=$BackupParentDir"logs/"

    # Creating necessary directories if needed
    if [ ! -d "$BackupParentDir" ]; then
        mkdir "$BackupParentDir"
    fi
    if [ ! -d "$LogsDir" ]; then
        mkdir "$LogsDir"
    fi

    # Creating log file
    touch "$LogsDir$CurrentDateTime.txt"

    RunBackup
fi
