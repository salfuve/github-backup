#!/bin/bash 

# NOTE: if you have more than 100 repositories, you'll need to step thru the list of repos 
# returned by GitHub one page at a time, as described at https://gist.github.com/darktim/5582423
echo -n "Enter your git username: "
read username
echo -n "Enter your git password: "
read -s password

GHBU_BACKUP_DIR=${GHBU_BACKUP_DIR-"github-backups"}                  # where to place the backup files
GHBU_ORG=${GHBU_ORG-"$username"}                                   # the GitHub organization whose repos will be backed up
                                                                   # (if you're backing up a user's repos instead, this should be your GitHub username)
GHBU_UNAME=${GHBU_UNAME-"$username"}                               # the username of a GitHub account (to use with the GitHub API)
GHBU_PASSWD=${GHBU_PASSWD-"$password"}                             # the password for that account 
GHBU_GITHOST=${GHBU_GITHOST-"https://github.com/"}                            # the GitHub hostname (see comments)
GHBU_PRUNE_OLD=${GHBU_PRUNE_OLD-true}                                # when `true`, old backups will be deleted
GHBU_PRUNE_AFTER_N_DAYS=${GHBU_PRUNE_AFTER_N_DAYS-3}                 # the min age (in days) of backup files to delete
GHBU_SILENT=${GHBU_SILENT-false}                                     # when `true`, only show error messages 
GHBU_API=${GHBU_API-"https://api.github.com"}                        # base URI for the GitHub API
GHBU_GIT_CLONE_CMD="git clone --quiet --mirror ${GHBU_GITHOST}" # base command to use to clone GitHub repos
# GHBU_GIT_PUSH_CMD="git push "
TSTAMP=`date "+%Y%m%d-%H%M"`
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

# The function `tgz` will create a gzipped tar archive of the specified file ($1) and then remove the original
function tgz {
   check tar zcf $1.tar.gz $1 && check rm -rf $1
}

$GHBU_SILENT || (echo "" && echo "=== INITIALIZING ===" && echo "")

$GHBU_SILENT || echo "Using backup directory $GHBU_BACKUP_DIR"
check mkdir -p $GHBU_BACKUP_DIR

$GHBU_SILENT || echo -n "Fetching list of repositories for ${GHBU_ORG}..."
#REPOLIST=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/orgs/${GHBU_ORG}/repos\?per_page=100 -q | check grep "\"name\"" | check awk -F': "' '{print $2}' | check sed -e 's/",//g'`
# NOTE: if you're backing up a *user's* repos, not an organizations, use this instead:
REPOLIST=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/user/repos\?per_page=100 -q | check grep "\"name\"" | check awk -F': "' '{print $2}' | check sed -e 's/",//g'`
$GHBU_SILENT || echo "found `echo $REPOLIST | wc -w` repositories."

$GHBU_SILENT || (echo "" && echo "=== BACKING UP LOCALLY ===" && echo "")
#Delete the restored repositories in order to create a new backup
for REPO in $REPOLIST; do

  if [[ "${REPO}" == *-restoredGHBU* ]];then

     curl -u $GHBU_UNAME:$GHBU_PASSWD -X DELETE https://api.github.com/repos/salfuve/${REPO}
     echo "repository ${REPO} deleted"

  fi
done

REPOLIST_AUX=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/user/repos\?per_page=100 -q | check grep "\"name\"" | check awk -F': "' '{print $2}' | check sed -e 's/",//g'`
for REPO in $REPOLIST_AUX; do

   $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${REPO}"
   check ${GHBU_GIT_CLONE_CMD}${GHBU_ORG}/${REPO}.git ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${REPO}-${TSTAMP}.git 
   $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${REPO}.wiki (if any)"
   git clone https://github.com/${GHBU_ORG}/${REPO}.wiki.git ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${REPO}.wiki-${TSTAMP}2>/dev/null 
   #state=all, an issue | pull | project can be either open, close or all
   $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${REPO} issues"
   check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${REPO}/issues\?state\=all -q > ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${REPO}-ISSUES-${TSTAMP}.txt
  $GHBU_SILENT || (echo "" && echo "=== BACKING UP LOCALLY ===" && echo "")
   
   #create a new repository with name $REPO-restoredGHBU
   curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/user/repos -d "{\"name\":\"${REPO}-restoredGHBU\"}"
   echo "Repository created"
   echo "Cloning into new repository..."
   #push the cloned repository into the new repository created
   cd ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${REPO}-${TSTAMP}.git 
   git push https://github.com/$GHBU_UNAME/${REPO}-restoredGHBU
   echo "Cloned"
   echo "Cloning Issues.."
   #push the Issues to Github
   ISSUELIST=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${REPO}/issues\?state\=all -q | check grep "\"number\"" | check awk -F': ' '{print $2}' | check sed -e 's/,//g'`
   for ISSUE in $ISSUELIST; do
      TITLE=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${REPO}/issues/${ISSUE} -q | check grep "\"title\"" | check awk -F': "' '{print $2}' | check sed -e 's/",//g'`
      BODY=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${REPO}/issues/${ISSUE} -q | check grep "\"body\"" | check awk -F': "' '{print $2}' | check sed -e 's/",//g'`
      LABELS=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${REPO}/issues/${ISSUE}  -q | check grep "\"name\"" | check awk -F': ' '{print $2}' | check sed -e 's/,//g'`
      curl -u $GHBU_UNAME:$GHBU_PASSWD -i -H "Content-Type: application/json" -X POST --data '{"title":"'$TITLE'", "body":"'$BODY'"}' https://api.github.com/repos/$GHBU_UNAME/${REPO}-restoredGHBU/issues
   done
   echo "Issues cloned"
   cd ..
   cd ..
done

if $GHBU_PRUNE_OLD; then
  $GHBU_SILENT || (echo "" && echo "=== PRUNING ===" && echo "")
  $GHBU_SILENT || echo "Pruning backup files ${GHBU_PRUNE_AFTER_N_DAYS} days old or older."
  $GHBU_SILENT || echo "Found `find $GHBU_BACKUP_DIR -name '*.tar.gz' -mtime +$GHBU_PRUNE_AFTER_N_DAYS | wc -l` files to prune."
  find $GHBU_BACKUP_DIR -name '*.tar.gz' -mtime +$GHBU_PRUNE_AFTER_N_DAYS -exec rm -fv {} > /dev/null \; 
fi

$GHBU_SILENT || (echo "" && echo "=== DONE ===" && echo "")
$GHBU_SILENT || (echo "GitHub backup completed." && echo "")