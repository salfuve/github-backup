#!/bin/bash 
GHBU_UNAME=${GHBU_UNAME-"$1"}                                 
GHBU_PASSWD=${GHBU_PASSWD-"$2"}                  
GHBU_ORG=${GHBU_ORG-"$3"}     
GHBU_1REPO=${GHBU_1REPO-"$4"}
GHBU_DATE=${GHBU_DATE-"$5"}           
GHBU_BACKUP_DIR=${GHBU_BACKUP_DIR-"github-backups"}             #repo you want to restore
GHBU_GITHOST=${GHBU_GITHOST-"https://github.com/"}                  
GHBU_SILENT=${GHBU_SILENT-false}                                    
GHBU_API=${GHBU_API-"https://api.github.com"}                       
GHBU_GIT_CLONE_CMD="git clone --quiet --mirror ${GHBU_GITHOST}" 

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
#Read issues from the local backup and post them into github
function getIssues {
   cd .. 
   ISSUELIST=`cat issuelist.txt`
        for ISSUE in $ISSUELIST; do
            TITLE=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${GHBU_1REPO}/issues/${ISSUE} -q | check grep "\"title\"" | check awk -F': "' '{print $2}' | check sed -e 's/",//g'`
            BODY=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${GHBU_1REPO}/issues/${ISSUE} -q | check grep "\"body\"" | check awk -F': "' '{print $2}' | check sed -e 's/",//g'`
            LABELS=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${GHBU_1REPO}/issues/${ISSUE}/labels  -q `
            echo '{"title": "'"$TITLE"'","body": "'"$BODY"'","labels": '$LABELS'}'>issues.txt
            curl -u $GHBU_UNAME:$GHBU_PASSWD -i -H "Content-Type: application/json" -X POST --data @issues.txt https://api.github.com/repos/$GHBU_UNAME/${GHBU_1REPO}-restoredGHBU/issues
        done
   echo "Issues restored"
}
#create a new repository with name $REPO-restoredGHBU
function createRepository {
    curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/user/repos -d "{\"name\":\"${GHBU_1REPO}-restoredGHBU\"}"
    echo "Repository created"
    echo "Cloning into new repository..."
    #push the cloned repository into the new repository created
    cd ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${GHBU_1REPO}-${GHBU_DATE}.git 
    git push https://github.com/$GHBU_UNAME/${GHBU_1REPO}-restoredGHBU
    echo "Cloned"
    echo "Restoring Issues.."
}
#Look inside a user's repository list and check if theres is a previus backup, if there's one, delete it.
function delete {
    echo "enter delete"
    for REPO in $REPOLIST; do 
        echo $REPO
        if [ "${REPO}" == "${GHBU_1REPO}-restoredGHBU" ]; then
            curl -u $GHBU_UNAME:$GHBU_PASSWD -X DELETE https://api.github.com/repos/$GHBU_UNAME/${REPO}
            echo "repository ${GHBU_1REPO}-restoredGHBU deleted"
        fi
    done
    }
#REPOLIST = list of user repositories in order to check if theres a previus restore
REPOLIST=`check curl --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/user/repos\?per_page=100 -q | check grep "\"name\"" | check awk -F': "' '{print $2}' | check sed -e 's/",//g'`
$GHBU_SILENT || (echo "" && echo "=== Initializing restore ===" && echo "")
$GHBU_SILENT || echo "Restoring $GHBU_1REPO"
#Look inide a user's repository list and check if theres is a previus backup, if there's one, delete it.
delete   
#create a new repository with name $REPO-restoredGHBU
createRepository
#get all the issues from the repository and push them to github
getIssues

$GHBU_SILENT || (echo "" && echo "=== DONE ===" && echo "")
$GHBU_SILENT || (echo "GitHub restore completed." && echo "")