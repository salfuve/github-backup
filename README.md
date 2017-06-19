# Backup and Restore
backup-git.sh creates a (local)backup of your repository including your code, your issues and wiki.
restore-git.sh restore a repository into github including code and Issues.
Due limitations of the GitHub API, the wiki can't be restored automatically and you have to restore it manually.

## Prerequisites
In order to use this script in Windows, you need to have installed Git

## Use
Download the script backhub-git.sh and open a bash console:

## Backup
$ ./backhub-git.sh username password organization repository destination 

(if the field destination is empty, the backup is the created by default in the same folder where the script is)
When the script is finished, a .tar has been created with:
    - repository.git
    - repository.wiki
    - Issues.json
    -  
 ## Restore
If you need to restore the repository into Githbu someday:

$ ./restore-git.sh username password organization repository date

'date' parameter is YearMonhtDay of the last backup (p.e 20170620)
