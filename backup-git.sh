#!/bin/bash 
GHBU_BACKUP_DIR=${GHBU_BACKUP_DIR-"github-backups"}   
GHBU_UNAME=${GHBU_UNAME-"$1"}                                 
GHBU_PASSWD=${GHBU_PASSWD-"$2"}                  # where to place the backup files
GHBU_ORG=${GHBU_ORG-"$3"}     
GHBU_1REPO=${GHBU_1REPO-"$4"}  
GHBU_PATH=${GHBU_PATH-"$5"}
GHBU_GITHOST=${GHBU_GITHOST-"https://github.com/"}                  
GHBU_PRUNE_OLD=${GHBU_PRUNE_OLD-true}                                # when `true`, old backups will be deleted
GHBU_PRUNE_AFTER_N_DAYS=${GHBU_PRUNE_AFTER_N_DAYS-3}                 # the min age (in days) of backup files to delete
GHBU_SILENT=${GHBU_SILENT-false}                                     # when `true`, only show error messages 
GHBU_API=${GHBU_API-"https://api.github.com"}                       
GHBU_GIT_CLONE_CMD="git clone --quiet --mirror ${GHBU_GITHOST}" 
TSTAMP=`date "+%Y%m%d"`

# The function `check` will exit the script if the given command fails.
function check {
  "$@"
  status=$?
  if [ $status -ne 0 ]; then
    echo "ERROR: Encountered error (${status}) while running the following:" >&2
    echo "           $@"  >&2
    echo "       (at line ${BASH_LINENO[0]} of file $0.)"  >&2
    echo "       Aborting." >&2
    exit $status
  fi
}

#start the backup locally
function backupLocally {

    $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${GHBU_1REPO}"
    check ${GHBU_GIT_CLONE_CMD}${GHBU_ORG}/${GHBU_1REPO}.git ${GHBU_PATH}${GHBU_BACKUP_DIR}/${GHBU_ORG}-${GHBU_1REPO}-${TSTAMP}.git 
    
    $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${GHBU_1REPO}.wiki (if any)"
    # ${GHBU_GIT_CLONE_CMD}${GHBU_ORG}/${GHBU_1REPO}.wiki.git ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${GHBU_1REPO}.wiki-${TSTAMP} 2>/dev/null 
    git clone https://github.com/${GHBU_ORG}/${GHBU_1REPO}.wiki.git ${GHBU_PATH}${GHBU_BACKUP_DIR}/${GHBU_ORG}-${GHBU_1REPO}.wiki-${TSTAMP} 2>/dev/null 

    #state=all, an issue | pull | project can be either open, close or all
    $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${GHBU_1REPO} issues"
    check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${GHBU_1REPO}/issues\?state\=all -q > ${GHBU_PATH}${GHBU_BACKUP_DIR}/${GHBU_ORG}-${GHBU_1REPO}-ISSUES-${TSTAMP}.json 

    $GHBU_SILENT || echo "Zipping files"

    cd ${GHBU_BACKUP_DIR}/
 #Get the issue's number in order to post them later into GIT 
    check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${GHBU_1REPO}/issues\?state\=all -q | check grep "\"number\"" | check awk -F': ' '{print $2}' | check sed -e 's/,//g'>issuelist.txt
 #zipp the files
    tar -cvf ${GHBU_ORG}-${GHBU_1REPO}-${TSTAMP}.tar ${GHBU_ORG}-${GHBU_1REPO}-${TSTAMP}.git ${GHBU_ORG}-${GHBU_1REPO}.wiki-${TSTAMP} ${GHBU_ORG}-${GHBU_1REPO}-ISSUES-${TSTAMP}.json 

    cd ..
}

$GHBU_SILENT || (echo "" && echo "=== INITIALIZING ===" && echo "")
$GHBU_SILENT || echo "Using backup directory ${GHBU_PATH}$GHBU_BACKUP_DIR"
check mkdir -p ${GHBU_PATH}$GHBU_BACKUP_DIR
$GHBU_SILENT || (echo "" && echo "=== BACKING UP LOCALLY ===" && echo "")

#start the backup locally
backupLocally

if $GHBU_PRUNE_OLD; then
  $GHBU_SILENT || (echo "" && echo "=== PRUNING ===" && echo "")
  $GHBU_SILENT || echo "Pruning backup files ${GHBU_PRUNE_AFTER_N_DAYS} days old or older."
  $GHBU_SILENT || echo "Found `find ${GHBU_PATH}$GHBU_BACKUP_DIR -name '*.tar.gz' -mtime +$GHBU_PRUNE_AFTER_N_DAYS | wc -l` files to prune."
  find ${GHBU_PATH}$GHBU_BACKUP_DIR -name '*.tar.gz' -mtime +$GHBU_PRUNE_AFTER_N_DAYS -exec rm -fv {} > /dev/null \; 
fi

$GHBU_SILENT || (echo "" && echo "=== DONE ===" && echo "")
$GHBU_SILENT || (echo "GitHub backup completed." && echo "")