# zfs_snapshot
Ruby script for creating periodic ZFS snapshots (incl. cleanup feature)

# Dependencies: 
- time_difference-gem

# Usage: 
Recommended to be used in combination with cron jobs to automate the cleanup / creation of snapshots. 
Needs root privileges for creating / destroying snapshots.

```
Usage: zfs_snapshot [options]
    -d, --dataset DATASET            ZFS Dataset to work on
    -t, --ttl TIME IN DAYS           Amount of time the snapshot should be valid, supported values hours(h), days(d), months(m), years(y)
    -n, --name SNAPSHOT NAME         Basic name of the snapshot
    -v, --verbose                    Output more information
    -i, --info                       Shows statistics about created snapshots
    -r, --recursive                  Create / Destroy ZFS Snapshots recursively
    -s, --safe                       Safe mode, dont execute actual command
    -c, --create                     Creates a new snapshot with the given values
    -p, --purge                      Deletes expired ZFS Snapshots
```

# Examples: 

Create new snapshot of tank-dataset that's valid for 30 days
``zfs_snapshot -c -d tank -t 30d``

Create new snapshot of tank-dataset that's valid for 30 weeks
``zfs_snapshot -c -d tank -t 30w``

Check for expired snapshots and automatically delete them
``zfs_snapshot -d tank -p``

# Example crontab
```
#Generate a new snapshot every hour thats valid for 12 hours
0 */2 * * * root ruby zfs_snapshot.rb -c -d tank/jails/services/jira -t 12h -n hourly >/dev/null 2>&1 

#Generate a new snapshot every day at midnight that's valid for 30 days
0 0 * * * root ruby zfs_snapshot.rb -c -d tank/jails/services/jira -t 30d -n daily >/dev/null 2>&1

#Generate a new snapshot at the beginning of a month at midnight that's valid for 3 months
0 0 1 * * root ruby zfs_snapshot.rb -c -d tank/jails/services/jira -t 3m -n monthly >/dev/null 2>&1

#Look for outdated snapshots every day at midnight and automatically delete them
0 0 * * * root ruby zfs_snapshot.rb -d tank/jails/services/jira -p >/dev/null 2>&1
```

# export snapshot

# Dependencies
- time_difference-gem

# Usage: 
Recommended to be used in combination with cron jobs to automate the replication / cleanup of snapshots to a remote ftp location. 

```
Usage: export_snapshots.rb [options]
	-d, --dataset DATASET 			 ZFS Dataset to work on
    -v, --verbose                    Output more information
    -s, --safe 						 Safe mode, dont execute actual command
    -u, --username USERNAME			 Remote FTP Username
    -p, --password PASSWORD 		 Remote FTP Password
    -h, --host HOST 				 Remote FTP Host
    -f, --folder FOLDER 			 Remote FTP destination folder
```

# Examples

Upload all snapshots and delete expired ones
``ruby export_snapshot.rb upload -h ftphost.de -u username -p password -f /Appenetic/FreeBSD/services/jira/zfs/ -d tank``