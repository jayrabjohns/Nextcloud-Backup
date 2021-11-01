#!/bin/bash

# Backup solution based on https://kevq.uk/how-to-backup-nextcloud/
# Argument passing based on https://www.redhat.com/sysadmin/arguments-options-bash-scripts

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

runBackup()
{
    SECONDS=0
    dataDir="${backupParentDir}data/"
    databaseDir="${backupParentDir}database/"
    oldDataDestinationDir="${backupParentDir}old/"
    metadataFile="${backupParentDir}backup_metadata"

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

    echo "Starting nextcloud backup..."

    # Compressing old backup, if data exists
    echo ""
    echo "--Compressing old backup...--"
    if [ -z "$(ls -A $dataDir)" ]; then
        echo "--Skipping compression of old backup because $dataDir is empty--";
    else
        start="$SECONDS"
        oldDate=$(grep -oP  "(?<=^date: ).*$" "$metadataFile")
        #echo "$oldDate"
        tar -zcf "${oldDataDestinationDir}${oldDate}.tar.gz" "$dataDir" "${databaseDir}db_export_${oldDate}.tar.gz" "${logsDir}${oldDate}.log"

        duration=$((SECONDS - start))
        echo "--Old backup compressed and moved to $oldDataDestinationDir in $((duration / 60)) minutes and $((duration % 60)) seconds--"
    fi

    # Creating new metadata file
    echo "date: $currentDateTime" > "${backupParentDir}backup_metadata"

    # Backup data
    echo ""
    echo "--Starting data backup...--"
    start=$SECONDS
    nextcloud.occ maintenance:mode --on
    rsync -Aavx "$dataSourceDir" "$dataDir"
    nextcloud.occ maintenance:mode --off
    duration=$((SECONDS - start))
    echo "--Data backup finished in $((duration / 60)) minutes and $((duration % 60)) seconds--"

    # Export apps, database, config
    echo ""
    echo "--Starting export of apps, database, and config...--" 
    start=$SECONDS
    nextcloud.export -abc

    # Compress export
    echo ""
    echo "--Compressing export...--"
    tar -zcf "${databaseDir}db_export_${currentDateTime}.tar.gz" /var/snap/nextcloud/common/backups/*
    duration=$((SECONDS - start))
    echo "--Exported compressed apps, database, and config to $databaseDir in $((duration / 60)) minutes and $((duration % 60)) seconds--"

    # Remove uncompressed export
    echo "--Removing uncompressed exports...--"
    start=$SECONDS
    rm -rf /var/snap/nextcloud/common/backups/*
    duration=$((SECONDS - start))
    echo "--Finished removing uncompressed exports in $((duration / 60)) minutes and $((duration % 60)) seconds"

    # Remove old backups older than 14 days
    echo "--Removing backups, logs, & database exports older than 14 days...--"
    start=$SECONDS
    find "$oldDataDestinationDir" -mtime +14 -type f -delete
    find "$databaseDir" -mtime +14 -type f -delete
    find "$logsDir" -mtime +14 -type f -delete
    duration=$((SECONDS - start))
    echo "--Old backups, logs, & database exports removed in $((duration / 60)) minutes and $((duration % 60)) seconds--"

    duration=$SECONDS
    echo "--Nextcloud backup completed successfully in $((duration / 60)) minutes and $((duration % 60)) seconds--"
}


############################################      Main      ############################################

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
        s) # Defines source directory
            dataSourceDir="$OPTARG";;
        d) # Defines destination directory
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
    echo "Provide a valid destination directory. (Be sure to include a slash at the end)"
    exit;
fi

logsDir="${backupParentDir}logs/"

# Creating necessary directories if needed
if [ ! -d "$backupParentDir" ]; then
    mkdir "$backupParentDir"
fi
if [ ! -d "$logsDir" ]; then
    mkdir "$logsDir"
fi

# Printing to log file and or stdout
if [ "$verbose" = true ]; then
    runBackup | tee "${logsDir}${currentDateTime}.log"
else
    runBackup > "${logsDir}${currentDateTime}.log"
fi
