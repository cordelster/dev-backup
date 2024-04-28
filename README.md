# device-backup-git
### This script is run daily on the Cisco switches
Stores in git enabled folder

# Description
This script allows network backups of Cisco switches and routers via ssh or telnet, Linux /etc/folders via rsync, config file can be encrypted using openssl, Netapp 1610 backup is also posible.


It stores the backed up configs in git repositories for version tracking.

# How to use

 -v verbose debug

 -c Commit comment

 -d backup git folder location  (already initialized)

 -f Device list

 -n list of lines in dev file to backup.

 -r Don't commit to GIT repositories

 -k ignore all ssh keys

 -b create startup-config with only all users, IP, gateway, snmp, and DNS appened file with RESET

 -B create startup-config with only admin password, IP, gateway, snmp, and DNS appened file with RESET

 -l List Device entries that will would run by hostname.

 -L List full lines from device file.

```sh
./device-backup-git.sh -f dev.lst -d ../backup/ -n 8 -c "some changes description"
```

```sh
./device-backup-git.sh -f dev.lst -d ../backup/ -n "29 30" -c "back up devices with number 29 and 30 from the configuration file"
```

```sh
./device-backup-git.sh -f dev.lst -d ../backup/ -c "backup all devices from the configuration file"
```

# Device file

Device options:

|Device Type | use | protocols |
|-----|-----|-----|
|ibmbnt|backup ibmbnt|telnet| 
|linux|Backup /etc via rsync|rsync, rsynclocal, rsyncsudo|
|cisco|Older cisco OS versions|telnet, ssh, sshnokey|
|nxos| Recent cisco OS|telnet, ssh, sshnokey|

|Connection Protocols| use |
|-----|-----|
|rsync|use rsync|
|rsynclocal|Run rsync locally|
|rsyncsudo|Run rsync with sudo privilege|
|ssh|Use ssh|
|sshnokey|Use ssh ignore all key errors for this device|
|telnet|Use telnet|

Device file format @ used as delimiter one device to each line:
 ```
 NUMBER@DEVICE_TYPE@CONNECTION_PROTOCOL@@DEVICE_USER@USER_PASSWORD@ENABLE_PASSWORD@DEVICE_ADDRESS@DEVICE_PORT
 ```


# cisco backup user example
```
username backup privilege 3 secret 0 PASSWORD
privilege exec all level 3 show running-config
```
