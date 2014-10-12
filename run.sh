#!/bin/bash

CONFIG_FILE="/etc/samba/smb.conf"

initialized=`getent passwd |grep -c '^smbuser:'`
set -e
if [ $initialized = "0" ]; then
  useradd smbuser -M

  cat >"$CONFIG_FILE" <<EOT
[global]
workgroup = WORKGROUP
security = user
create mask = 0664
directory mask = 0775
force create mode = 0664
force directory mode = 0775
force user = smbuser
force group = smbuser
load printers = no
printing = bsd
printcap name = /dev/null
disable spoolss = yes
EOT

  while getopts ":u:s:h" opt; do
    case $opt in
      h)
        cat <<EOH
Samba server container

Container will be configured as samba sharing server and it just needs:
 * host directories to be mounted,
 * users (one or more username:password tuples) provided,
 * shares defined (name, path, users).

 -u username:password         add user account (named 'username'), which is
                              protected by 'password'

 -s name:path:rw:user1[,user2[,userN]]
                              add share, that is visible as 'name', exposing
                              contents of 'path' directory for read+write (rw)
                              or read-only (ro) access for specified logins
                              user1, user2, .., userN

Example:
docker run -d -p 445:445 \\
  -v /mnt/data:/share/data \\
  -v /mnt/backups:/share/backups \\
  trnape/rpi-samba \\
  -u "alice:abc123" \\
  -u "bob:secret" \\
  -u "guest:guest" \\
  -s "Backup directory:/share/backups:rw:alice,bob" \\
  -s "Alice (private):/share/data/alice:rw:alice" \\
  -s "Bob (private):/share/data/bob:rw:bob" \\
  -s "Documents (readonly):/share/data/documents:ro:guest,alice,bob"

EOH
        exit 1
        ;;
      u)
        echo -n "Add user "
        IFS=: read username password <<<"$OPTARG"
        echo -n "'$username' "
        useradd "$username" -M
        echo -n "with password '$password' "
        echo "$password" |tee - |smbpasswd -s -a "$username"
        echo "DONE"
        ;;
      s)
        echo -n "Add share "
        IFS=: read sharename sharepath readwrite users <<<"$OPTARG"
        echo -n "'$sharename' "
        echo "[$sharename]" >>"$CONFIG_FILE"
        chown smbuser "$sharepath"
        echo -n "path '$sharepath' "
        echo "path = \"$sharepath\"" >>"$CONFIG_FILE"
        echo -n "read"
        if [[ "rw" = "$readwrite" ]] ; then
          echo -n "+write "
          echo "read only = no" >>"$CONFIG_FILE"
        else
          echo -n "-only "
          echo "read only = yes" >>"$CONFIG_FILE"
        fi
        echo -n "for users: "
        users=$(echo "$users" |tr "," " ")
        echo -n "$users "
        echo "valid users = $users" >>"$CONFIG_FILE"
        echo "DONE"
        ;;
      \?)
        echo "Invalid option: -$OPTARG"
        exit 1
        ;;
      :)
        echo "Option -$OPTARG requires an argument."
        exit 1
        ;;
    esac
  done

fi

exec ionice -c 3 smbd -FS --configfile="$CONFIG_FILE"
