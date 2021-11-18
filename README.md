# Backup script for a Nextcloud server

Incrementally backs up data stored.

Optionally allows you to compress & keep old backups.
Additionally, it can delete backups after they become a given number of days old.

Includes data, apps, database, and config.

Compatible with Nextcloud's server side encryption settings.

Currently does not include functionality for restoring a backup.

This was developed on Ubuntu 20.04.3 LTS and has not been tested on other systems.

It's recommended to run this as a cron job, frequency depends on your needs.
