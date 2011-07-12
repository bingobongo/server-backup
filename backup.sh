#!/bin/sh


# CONFIGURATION SECTION
# ---------------------

# The primary user name that is used to login to the
# (Shared) SmartMachine.

JOY=username


# The MySQL user name, password and a space-separated
# list of MySQL database names to backup.

MY_UN=db-username
MY_PW=db-password
MY_DB='db-name-1 db-name-2'


# The Strongspace SSH alias name
# (i.e. the before defined Host in .ssh/config file).

SS_ALIAS=ss


# The base directory plus its five subdirectory names
# (used for the rotation purpose) under which to store
# the backup on Strongspace.

SS_BASE=/strongspace/username/space-name
SS_NAME_1=subdirectory-name-1
SS_NAME_2=subdirectory-name-2
SS_NAME_3=subdirectory-name-3
SS_NAME_4=subdirectory-name-4
SS_NAME_5=subdirectory-name-5


# How many days to keep the database backups for;
# e.g. for a backup once a week and wanting to keep
# eight backups on the disk, set this to 56.

MTIME=56


# DO NOT EDIT TOO MUCH BELOW HERE, UNLESS ONE IS DOING SOMETHING CUSTOM
# ---------------------------------------------------------------------


# Define pathes (i.e. "/users/home/username").
# NOTE that on a Joyent SmartMachine JOY_DIR
# may be "/home/${JOY}" or similar, whereat on a
# Shared SmartMachine it would be "/users/home/${JOY}".

DATESTAMP=`date "+%Y-%m-%d"`
JOY_DIR="/users/home/${JOY}"
JOY_BACKUP_DIR="${JOY_DIR}/backup"


# Remember the last rotated backup destination.

if [ ! -f ${JOY_BACKUP_DIR}/${SS_NAME_1} ] && [ ! -f ${JOY_BACKUP_DIR}/${SS_NAME_2} ] && [ ! -f ${JOY_BACKUP_DIR}/${SS_NAME_3} ] && [ ! -f ${JOY_BACKUP_DIR}/${SS_NAME_4} ] && [ ! -f ${JOY_BACKUP_DIR}/${SS_NAME_5} ]; then
	/usr/bin/touch ${JOY_BACKUP_DIR}/${SS_NAME_1}
	SS_DIR="${SS_BASE}/${SS_NAME_1}"
elif [ -f ${JOY_BACKUP_DIR}/${SS_NAME_1} ]; then
	/usr/bin/mv ${JOY_BACKUP_DIR}/${SS_NAME_1} ${JOY_BACKUP_DIR}/${SS_NAME_2}
	SS_DIR="${SS_BASE}/${SS_NAME_2}"
elif [ -f ${JOY_BACKUP_DIR}/${SS_NAME_2} ]; then
	/usr/bin/mv ${JOY_BACKUP_DIR}/${SS_NAME_2} ${JOY_BACKUP_DIR}/${SS_NAME_3}
	SS_DIR="${SS_BASE}/${SS_NAME_3}"
elif [ -f ${JOY_BACKUP_DIR}/${SS_NAME_3} ]; then
	/usr/bin/mv ${JOY_BACKUP_DIR}/${SS_NAME_3} ${JOY_BACKUP_DIR}/${SS_NAME_4}
	SS_DIR="${SS_BASE}/${SS_NAME_4}"
elif [ -f ${JOY_BACKUP_DIR}/${SS_NAME_4} ]; then
	/usr/bin/mv ${JOY_BACKUP_DIR}/${SS_NAME_4} ${JOY_BACKUP_DIR}/${SS_NAME_5}
	SS_DIR="${SS_BASE}/${SS_NAME_5}"
else 
	/usr/bin/mv ${JOY_BACKUP_DIR}/${SS_NAME_5} ${JOY_BACKUP_DIR}/${SS_NAME_1}
	SS_DIR="${SS_BASE}/${SS_NAME_1}"
fi


# Backup the MySQL databases.

for db in ${MY_DB}; do
	/usr/bin/mkdir -p ${JOY_BACKUP_DIR}/mysql/${db}
	/usr/local/bin/mysqldump --user=${MY_UN} --password=${MY_PW} -Q --database ${db} > ${JOY_BACKUP_DIR}/mysql/${db}/${DATESTAMP}.sql
	/usr/bin/find ${JOY_BACKUP_DIR}/mysql/${db}/*.sql -mtime +${MTIME} -exec /usr/bin/rm {} \;
done


# Run the backup.
# NOTE that on a Joyent SmartMachine rsync
# resides in "/opt/local/bin/rsync", whereat on a
# Shared SmartMachine it is "/usr/local/bin/rsync".

/usr/local/bin/rsync -rltpqz --delete --delete-after --exclude-from "${JOY_BACKUP_DIR}/exclude.txt" ${JOY_DIR}/ ${SS_ALIAS}:${SS_DIR}
