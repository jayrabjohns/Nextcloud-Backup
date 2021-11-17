# Backup script for Nextcloud

Incrementally backs up data stored using nextcloud.

Optionally allows you to compress & keep old backups.
Additionally to this can delete old backups a given number of days old

Includes Nextcloud data, apps, databases, and config.

Compatible with Nextcloud's server side encryption.

Currently does not include functionality for restoring a backup.

It's recommended to run this as a cron job, frequency depends on your needs.
