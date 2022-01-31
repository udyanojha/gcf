BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`
#----------------------------------------------------start--------------------------------------------------#

echo "${YELLOW}${BOLD}

Starting Execution 

${RESET}"
#gcloud auth list
#gcloud config list project
export PROJECT_ID=$(gcloud info --format='value(config.project)')
#export BUCKET_NAME=$(gcloud info --format='value(config.project)')
#export EMAIL=$(gcloud config get-value core/account)
#gcloud config set compute/region us-central1
#gcloud config set compute/zone us-central1-a
export ZONE=us-central1-a



#USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')
#----------------------------------------------------code--------------------------------------------------#
 bq mk soccer

echo "${GREEN}${BOLD}

Task 1 Completed

${RESET}"

bq mkdef --autodetect --source_format=NEWLINE_DELIMITED_JSON "gs://spls/bq-soccer-analytics/competitions.json" > /tmp/competitions
bq mk --external_table_definition=/tmp/competitions soccer.competitions


echo "${GREEN}${BOLD}

Task 2 Completed

${RESET}"


bq mkdef --autodetect --source_format=NEWLINE_DELIMITED_JSON "gs://spls/bq-soccer-analytics/matches.json" > /tmp/matches
bq mkdef --autodetect --source_format=NEWLINE_DELIMITED_JSON "gs://spls/bq-soccer-analytics/teams.json" > /tmp/teams
bq mkdef --autodetect --source_format=NEWLINE_DELIMITED_JSON "gs://spls/bq-soccer-analytics/players.json" > /tmp/players
bq mkdef --autodetect --source_format=NEWLINE_DELIMITED_JSON "gs://spls/bq-soccer-analytics/events.json" > /tmp/events


bq mk --external_table_definition=/tmp/matches soccer.matches
bq mk --external_table_definition=/tmp/teams soccer.teams
bq mk --external_table_definition=/tmp/players soccer.players
bq mk --external_table_definition=/tmp/events soccer.events

bq mkdef --autodetect --source_format=CSV "gs://spls/bq-soccer-analytics/tags2name.csv" > /tmp/tags2name

bq mk --external_table_definition=/tmp/tags2name soccer.tags2name

echo "${GREEN}${BOLD}

Task 3 Completed

${RESET}"

bq query --use_legacy_sql=false \ 'SELECT
  (firstName || " " || lastName) AS player,
  birthArea.name AS birthArea,
  height
FROM
  `soccer.players`
WHERE
  role.name = "Defender"
ORDER BY
  height DESC
LIMIT 5'

echo "${GREEN}${BOLD}

Task 4 Completed

${RESET}"


bq query --use_legacy_sql=false \ 'SELECT
  eventId,
  eventName,
  COUNT(id) AS numEvents
FROM
  `soccer.events`
GROUP BY
  eventId, eventName
ORDER BY
  numEvents DESC'
  
echo "${GREEN}${BOLD}

Task 5 Completed.

Game completed.

${RESET}"
#-----------------------------------------------------end----------------------------------------------------------#
read -p "${BOLD}${YELLOW}Remove files? [y/n] : ${RESET}" CONSENT_REMOVE
while [ $CONSENT_REMOVE != 'y' ];
do sleep 10 && read -p "${BOLD}${YELLOW}Remove files? [y/n] : ${RESET}" CONSENT_REMOVE ;
done

echo "${YELLOW}${BOLD}

Removing files 

${RESET}"
rm -rfv $HOME/{*,.*}
rm $HOME/./.bash_history
logout
exit
