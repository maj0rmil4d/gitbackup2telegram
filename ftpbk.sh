
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/:/usr/local/bin/:/root/gitlab_BK
#
# FTP Bash Backup.
# Copyright (C) 2015 Johnnywoof
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

# FTP server settings
USERNAME="FTPUSER"
PASSWORD="FTPPASS"
SERVER="FTPSERVER"
PORT=21

# Remote server directory to upload backup
BACKUPDIR="/"

# Backups older than ndays will be removed
ndays=5

# The absolute local directory to pickup *.tar.gz file
# Please do not end the path with a forward slash.
LOCAL_DIRECTORY="/root/gitlab_BK/backups"

# The absolute directory path to store temporary files in.
# This must be granted write access for this script.
# Please do not end the path with a forward slash.
TEMP_BACKUP_STORE="/tmp"

# Please note that if you want to support encryption for backups, openssl must be installed.
# Should backups be encrypted before uploading?
ENCRYPT_BACKUP=false

# The absolute file path to the AES password.
# You can generate a random password using the following command:
# openssl rand -base64 256 > aes.key
# The number 256 is the amount of bytes to generate.
AES_PASSWORD_FILE=""

# END CONFIGURATION
# Script below, no need to modify it

RANDOM=$(date +%s)
timestamp=$(date --iso)

backup_remote_file_name="BK-$RANDOM-$timestamp.tar.gz"
backup_file="$TEMP_BACKUP_STORE/$backup_remote_file_name"


# work out our cutoff date
MM=`date --date="$ndays days ago" +%b`
DD=`date --date="$ndays days ago" +%d`

echo "Removing files older than $MM $DD"

# get directory listing from remote source
listing=`ftp -p -i -n $SERVER $PORT <<EOMYF
user $USERNAME $PASSWORD
binary
cd $BACKUPDIR
ls
quit
EOMYF
`
lista=( $listing )

# loop over our files
for ((FNO=0; FNO<${#lista[@]}; FNO+=9));do
  # month (element 5), day (element 6) and filename (element 8)
  #echo Date ${lista[`expr $FNO+5`]} ${lista[`expr $FNO+6`]}          File: ${lista[`expr $FNO+8`]}

  # check the date stamp
  if [ ${lista[`expr $FNO+5`]}=$MM ];
  then
    if [[ ${lista[`expr $FNO+6`]} -lt $DD ]];
    then
      # Remove this file
      echo "Removing ${lista[`expr $FNO+8`]}"
      ftp -p -i -n $SERVER $PORT <<EOMYF2
      user $USERNAME $PASSWORD
      binary
      cd $BACKUPDIR
      delete ${lista[`expr $FNO+8`]}
      quit
EOMYF2
    fi
  fi
done

echo "Creating backup..."

tar -czvf $backup_file $LOCAL_DIRECTORY

if [ "$ENCRYPT_BACKUP" == "true" ]
then
      echo "Encrypting backup using OpenSSL..."
      output_encrypted_file="$backup_file.enc"
      openssl enc -aes-256-cbc -salt -in $backup_file -out $output_encrypted_file -pass file:$AES_PASSWORD_FILE
      rm $backup_file
      backup_file=$output_encrypted_file
fi

echo "Uploading backup $backup_file ..."

ftp -p -n -i $SERVER $PORT <<EOF
user $USERNAME $PASSWORD
binary
cd $BACKUPDIR
put $backup_file $backup_remote_file_name
quit
EOF

echo "Deleting temporary files..."
rm $backup_file
echo "Backup complete."
