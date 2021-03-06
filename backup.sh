#!/usr/bin/bash
#
# Automated, rotating server backup to Strongspace
#
# @version    0.2
# @author     Markus Mayer
# @license    MIT License
# @copyright  2012- Markus Mayer
# @link       http://doogvaard.net/server-backup


# CONFIGURATION SECTION
# ---------------------

# The email address to which error messages are sent.
# Leave it blank to turn it off.

RECIPIENT="name@domain.tld"

# The pathname of the directory where the exclude-text-files
# are stored and where to store backups, log, etc.
# For example "/root/backup" or "/home/username/backup"
# or similar, whereat on a TextDrive Shared it probably
# would be "/users/home/username/backup". If its name
# is different from "backup", align the patterns inside
# "exclude-tar.txt" and, if not omitted, "exclude-rsync.txt"
# accordingly.

DESTINATION="/pathname/backup"

# A space-separated list of directory/file pathnames
# to backup. On a TextDrive Shared this might be
# "/users/home/username" or a subdirectory/file thereof.

PATHNAMES="/pathname/directory /pathname/file.ext"

# How many days to keep database dumps and tarballs for;
# e.g. for a backup once a week and keeping eight backups
# on the disk, set this to 56.

MTIME=56

# The MySQL user name, password and a space-separated
# list of MySQL database names to backup; optionally.

MYSQL_USER="db-username"
MYSQL_PASSWD="db-password"
MYSQL_NAMES="db-name-1 db-name-2"

# The SSH alias name used for the connection to Strongspace,
# i.e. the before defined Host in ~/.ssh/config file.

SS_ALIAS="ss"

# The pathname of the base directory on Strongspace,
# i.e. the pathname of the Strongspace Space.

SS_BASE="/strongspace/username/space-name"

# A space-separated list of subdirectory names where to
# store and rotate the backup in the Strongspace Space.
# Note that the subdirectories must have been created
# manually before running the backup the first time.

SS_DIRS="subdir-name-1 subdir-name-2"

# The prefix of the backup destination mark for superb
# readability and the basename used for naming database
# dumps, tarballs. Can be left as is.

SS_PREFIX="_recently_synced_with_"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")

# -----------------
# CONFIGURATION END


# DO NOT CHANGE TOO MUCH BELOW HERE,
# UNLESS ONE IS DOING SOMETHING CUSTOM.
# -------------------------------------

# Note that the pathes to some utilities might
# differ depending on the respective server.
# Make sure that the correct pathes are noted.
# This is particularly true for rsync, tar, mysqldump.

# Sets user name and log path for safety's sake.

[[ -n ${USERNAME} ]] || USERNAME="$(id -un)"
[[ -d ${DESTINATION} ]] && LOGFILE="${DESTINATION}/backup.log" || LOGFILE=/dev/null

usage()
{
  local bold=$(tput bold)
  local normal=$(tput sgr0)
  local NAMED=${bold}${0##*/}${normal}
  echo "\
  Usage: ${NAMED} [-h]
         ${NAMED} [-vlLU]"
  exit
}

log()
{
  echo -e "${1}"
  if [[ -n ${2} ]]; then
    [[ ${2} -gt 0 && ! $VERBOSE ]] && notify
    cat << EOF
  $(date "+%F %T")
* -------------------
EOF
    exit "${2}"
  fi
  return 0
}

notify()
{
  # Verifies postfix is running and recipient email specified.
  # Note that svcs is available on Illumos/SmartOS/Solaris only.
  # Instead, try e.g. service and adjust the pipe accordingly.

  if [[ $(svcs -v | grep -c "postfix") -ne 0 && \
    -n ${RECIPIENT} && ${RECIPIENT} != "name@domain.tld" ]]
  then
    [[ -n ${HOSTNAME} ]] || HOSTNAME="$(hostname)"
    local SERVERNAME=${HOSTNAME%%.*}
    rmail ${RECIPIENT} << EOF
from: ${USERNAME^} <noreply@${HOSTNAME}>
subject: ${SERVERNAME^} backup failed.
Read the log file '${LOGFILE}' for details.
EOF
    [[ $? -eq 0 ]] && \
      log "  Notified '${RECIPIENT%.*}####'." || \
      log "  Failed to notify '${RECIPIENT%.*}####'."
  fi
}

backup_mysql()
{
  [[ -n ${1} ]] || return 1
  if mkdir -m 700 -p ${DESTINATION}/mysql/${1}; then
    local ERROR=$({ /opt/local/bin/mysqldump --user=${MYSQL_USER} --password=${MYSQL_PASSWD} \
      -Q --database ${1} | gzip > ${DESTINATION}/mysql/${1}/${TIMESTAMP}.sql.gz; } 2>&1 )

    if [[ -z ${ERROR} ]]; then
      log "* Dumped MySQL database '${1}' to 'mysql/${1}/${TIMESTAMP}.sql.gz'."
      remove_outdated ${DESTINATION}/mysql/${1}/*.sql.gz
      return 0
    else
      rm -f ${DESTINATION}/mysql/${1}/${TIMESTAMP}.sql.gz
      ERROR="\n  ${ERROR}"
    fi
  fi
  log "* ERROR - Failed to backup MySQL database '${1}'.${ERROR}"; return 2
}

backup_pathname()
{
  [[ -n ${1} ]] || return 1
  local FLAT=${1//\//_}; FLAT=${FLAT#_}
  if mkdir -m 700 -p ${DESTINATION}/tar/${FLAT} && \
     /opt/local/bin/gtar -pszcf ${DESTINATION}/tar/${FLAT}/${TIMESTAMP}.tar.gz \
       --exclude-from ${DESTINATION}/exclude-tar.txt --warning none -C / ${1#/}
  then
    log "* Dumped '${1}' to 'tar/${FLAT}/${TIMESTAMP}.tar.gz'."
  else
    log "* ERROR - Failed to backup '${1}'."; return 2
  fi
  if [[ ! $LOCALONLY && -d ${1} && ! -d ${DESTINATION}/data/${FLAT} ]]; then
    mkdir -m 700 -p ${DESTINATION}/data/${FLAT} && \
      log "  Created placeholder 'data/${FLAT}'." || \
      log "  WARNING - Failed to create placeholder for directory '${1}'."
  fi
  remove_outdated ${DESTINATION}/tar/${FLAT}/*.tar.gz
}

remove_outdated()
{
  [[ -n ${1} ]] || return 1
  local OUTDATED=$(find ${1} -mtime +${MTIME})
  if [[ -n ${OUTDATED} ]]; then
    rm -f ${OUTDATED} && log "  Removed outdated dumps." || \
      log "  WARNING - Failed to remove outdated dumps."
  fi
}

remove_unlisted()
{
  [[ -n ${1} && -d ${DESTINATION}/${1} && -n ${2} ]] || return 1
  local LISTPATH="${DESTINATION}/${1}"
  local LIST="${2}"

  # Flattens pathnames for comparison.

  local FLAT=; local NAME=
  for PATHNAME in ${LIST}; do
    FLAT=${PATHNAME//\//_}; FLAT=${FLAT#_}
    NAME="${NAME} ${FLAT}"
  done
  LIST=${NAME# }

  for PATHNAME in ${LISTPATH}/*/; do
    PATHNAME=${PATHNAME%*/}
    NAME="${PATHNAME##*/}"
    [[ ${NAME} == "*" ]] && continue
    is_listed ${NAME} "${LIST}"
    if [[ $? -gt 1 ]]; then
      rm -rf ${PATHNAME} && log "* Removed unlisted '${1}/${NAME}'." || \
        log "* WARNING - Failed to remove unlisted '${1}/${NAME}'."
    fi
  done
}

is_listed()
{
  [[ -n ${1} && -n ${2} ]] || return 1
  for LISTED in ${2}; do
    [[ ${LISTED} == ${1} ]] && return
  done
  return 2
}

sync_pathname()
{
  [[ -n ${1} && -d ${1} ]] || return 1
  local FLAT=${1//\//_}; FLAT=${FLAT#_}
  [[ -d ${DESTINATION}/data/${FLAT} ]] || \
    { log "* ERROR - No placeholder found for '${1}', synchronization abandoned."; return 2; }
  /opt/local/bin/rsync ${RSYNC_OPTION} --delete --delete-after \
    ${EXCLUDE_FROM_RSYNC} ${1}/ ${SS_ALIAS}:${SS_PATH}/data/${FLAT} && \
    log "* Synced directory '${1}'." || \
    { log "* ERROR - Failed to synchronize directory '${1}'."; return 2; }
}

run_backup()
{
  local TEMP=

  # Empties the log file.

  [[ $LOGRESET && -f "${LOGFILE}" ]] && $(> "${LOGFILE}") && log "* Emptied log file '${LOGFILE}'."

  # Sets rsync options corresponding to user name.

  RSYNC_OPTION="-azq"
  [[ ${USERNAME} == "root" ]] || { echo "
* WARNING - Not running as root, but as ${USERNAME}.
  rsync executes with options '-rlptzq' instead of '-azq'."; RSYNC_OPTION="-rlptzq"; }

  # Verifies destination path.

  [[ -e ${DESTINATION} ]] || \
    log "* ERROR - DESTINATION '${DESTINATION}' doesn't exist." 2
  [[ -d ${DESTINATION} ]] || \
    log "* ERROR - DESTINATION '${DESTINATION}' is not a directory." 2

  # Prevents from configuration bubkis.

  if [[ ! $LOCALONLY ]]; then

    # Seeks for recently used subdirectory name.

    for NAME in ${SS_DIRS}; do
      [[ -z ${FUTURE} && ! -f ${DESTINATION}/${SS_PREFIX}${NAME} ]] && FUTURE=${NAME}
      if [[ -z ${RECENT} ]]; then
        [[ -f ${DESTINATION}/${SS_PREFIX}${NAME} ]] && RECENT=${NAME}
        continue
      else
        FUTURE=${NAME}; break
      fi
    done

    [[ -z ${SS_ALIAS} ]] && \
      log "* ERROR - Undefined SS_ALIAS." 2
    [[ -z ${SS_BASE} || ${SS_BASE} == "/strongspace/username/space-name" ]] && \
      log "* ERROR - SS_BASE '${SS_BASE}' is not advisable." 2
    [[ -z ${SS_DIRS} || "${SS_DIRS}" == "subdir-name-1 subdir-name-2" ]] && \
      log "* ERROR - SS_DIRS '${SS_DIRS}' is not advisable." 2
    [[ -z ${FUTURE} ]] && \
      log "* ERROR - Undefined FUTURE, failed to set SS_PATH." 2
    [[ -f ${DESTINATION}/exclude-rsync.txt ]] && \
      EXCLUDE_FROM_RSYNC="--exclude-from ${DESTINATION}/exclude-rsync.txt"
    SS_PATH="${SS_BASE}/${FUTURE}" # Sets full Strongspace pathname.
  fi

  # Verifies existence of pathnames.

  for PATHNAME in ${PATHNAMES}; do
    [[ -e ${PATHNAME} ]] && TEMP="${TEMP} ${PATHNAME}" || \
      log "* WARNING - '${PATHNAME}' doesn't exist."
  done
  PATHNAMES=${TEMP# }; TEMP=

  # Makes backup of directory, file.

  if [[ -n ${PATHNAMES} ]]; then

    # Verifies existence of exclude-tar.txt.

    [[ -f ${DESTINATION}/exclude-tar.txt ]] || \
      log "* ERROR - File '${DESTINATION}/exclude-tar.txt' doesn't exist." 2

    for PATHNAME in ${PATHNAMES}; do
      backup_pathname ${PATHNAME}
    done
  else
    log "* WARNING - No PATHNAMES found, its backup abandoned."
  fi

  # Makes backup of database.

  if [[ -z "${MYSQL_USER}"   || "${MYSQL_USER}" == "db-username" || \
        -z "${MYSQL_PASSWD}" || "${MYSQL_PASSWD}" == "db-password" || \
        -z "${MYSQL_NAMES}"  || "${MYSQL_NAMES}" == "db-name-1 db-name-2" \
  ]]; then
    log "* WARNING - MySQL setup is not advisable, its backup abandoned."
  else
    for NAME in ${MYSQL_NAMES}; do
      backup_mysql ${NAME}
    done
  fi

  # Removes backup of unlisted database, directory, file.

  if [[ $DELETE_UNLISTED ]]; then
    remove_unlisted "tar" "${PATHNAMES}"
    remove_unlisted "data" "${PATHNAMES}"
    remove_unlisted "mysql" "${MYSQL_NAMES}"
  fi

  if [[ ! $LOCALONLY ]]; then

    # Synchronizes the backup.
    # To test rsync manually with progress and stats (note to replace
    # options "-azq" with "-rlptzq" when not running as root), e.g.
    # rsync -azvv --delete --delete-after --stats --progress /DESTINATION/backup/ ss:/strongspace/USERNAME/SPACE-NAME/SUBDIRECTORY-NAME

    /opt/local/bin/rsync ${RSYNC_OPTION} --delete --delete-after ${DESTINATION}/ ${SS_ALIAS}:${SS_PATH} && \
      log "* Synced directory '${DESTINATION}'." || \
      log "* ERROR - Failed to synchronize directory '${DESTINATION}'." 2

    # Remembers the last rotated backup destination.

    if [[ -n ${RECENT} && -n ${FUTURE} ]]; then
      mv ${DESTINATION}/${SS_PREFIX}${RECENT} ${DESTINATION}/${SS_PREFIX}${FUTURE} && \
        log "* Updated destination mark '${SS_PREFIX}${RECENT}' to '${FUTURE}'." || \
        log "* ERROR - Failed to update destination mark '${SS_PREFIX}${RECENT}'." 2
    else
      touch ${DESTINATION}/${SS_PREFIX}${FUTURE} && \
        log "* Created destination mark '${SS_PREFIX}${FUTURE}'." || \
        log "* ERROR - Failed to create destination mark '${SS_PREFIX}${FUTURE}'." 2
    fi

    # Pathname synchronization comes last.

    if [[ -n ${PATHNAMES} ]]; then
      for PATHNAME in ${PATHNAMES}; do
        sync_pathname ${PATHNAME}
      done
    fi
  fi

  log "* Finished, m'Lord." 0
}

# Checks if verbose mode (writes messages to bash instead of log file,
# also turns off email notification), local-only (without rsync) and
# if the log file shall be emptied and unlisted backup be removed.

while getopts ":vhlLU-:" OPTION; do
  case $OPTION in
    -)
      case "${OPTARG}" in
        verbose)
          VERBOSE="verbose"
          ;;
        help)
          usage
          ;;
        localonly)
          LOCALONLY="local-only"
          ;;
        resetlog)
          LOGRESET="reset-log"
          ;;
        deleteunlisted)
          DELETE_UNLISTED="delete-unlisted"
          ;;
        *)
          log "* ERROR - Invalid option '--${OPTARG}'." 2
          ;;
      esac
      ;;
    v)
      VERBOSE="verbose"
      ;;
    h)
      usage
      ;;
    l)
      LOCALONLY="local-only"
      ;;
    L)
      LOGRESET="reset-log"
      ;;
    U)
      DELETE_UNLISTED="delete-unlisted"
      ;;
    \?)
      log "* ERROR - Invalid option '-${OPTARG}'." 2
      ;;
  esac
done

# Runs the backup.

[[ ! $VERBOSE ]] && run_backup 2>&1 >> ${LOGFILE} || run_backup
