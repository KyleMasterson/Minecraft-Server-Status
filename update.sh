#!/bin/bash

PLAYERDATA="${1}"
USERNAMECACHE="${2}"
DOMAIN="${3}"
BUCKET="${4}"

source /home/ec2-user/live/minecraft/.rcon-cli.env

CLUSTER="minecraft"
SERVICE_NAME="minecraft-server"

TASK_ARN=$(aws ecs --region ca-central-1 list-tasks --cluster "$CLUSTER" --service-name "$SERVICE_NAME" --query 'taskArns[0]' --output text)
TASK_DETAILS=$(aws ecs --region ca-central-1 describe-tasks --cluster "$CLUSTER" --task "${TASK_ARN}" --query 'tasks[0].attachments[0].details')
IP=$(echo $TASK_DETAILS | jq -r '.[] | select(.name=="privateIPv4Address").value')
PORT="25575"

ALL_USERS=$(ls "${PLAYERDATA}" | grep ".dat_old" | sed 's/.dat_old//g' | uniq)

result=$(./rcon -a "${IP}:${PORT}" -p "${password}" "list uuids")
result_status=$?

if [ $result_status -eq 0 ]; then
  ONLINE_COUNT=$(echo ${result} | sed 's/There are //g' | cut -c1-2 | xargs)
  MAX=$(echo ${result} | sed "s/There are ${ONLINE_COUNT} of a max of //g" | cut -c1-2 | xargs)
  PLAYERS=$(echo ${result} | sed "s/There are ${ONLINE_COUNT} of a max of ${MAX} players online: //g")
  while IFS="," read -r player; do
    username=$(echo ${player} | cut -d" " -f 1)
    uuid=$(echo ${player} | cut -d" " -f 2 | sed 's/(//g' | sed 's/)//g')
    item="<li class=\"image-list-item online\"><img src=\"https://mc-heads.net/avatar/${uuid}\" title=\"${username}\" alt=\"${username}\" style=\"--url: url('https://mc-heads.net/body/${uuid}');\"></li>"
    ONLINE_USERS="${item}${ONLINE_USERS}"
    ALL_USERS=$(echo "${ALL_USERS}" | grep -v "$uuid")
  done <<< "${PLAYERS}"
  STATUS="UP"
  STATUS_COLOUR="limegreen"
  SHOW_FOOTER="0"
else
  STATUS="DOWN"
  STATUS_COLOUR="red"
  SHOW_FOOTER="1"
fi

OFFLINE_COUNT=$(echo "$ALL_USERS" | wc -l)
while IFS="\n" read -r uuid; do
  username=$(jq -r ".\"$uuid\"" "${USERNAMECACHE}")
  item="<li class=\"image-list-item offline\"><img src=\"https://mc-heads.net/avatar/${uuid}\" title=\"${username}\" alt=\"${username}\"></li>"
  OFFLINE_USERS="${item}${OFFLINE_USERS}"
done <<< "${ALL_USERS}"

cp template.html status.html
sed -i -e "s/__STATUS__/${STATUS}/g" status.html
sed -i -e "s|__STATUS_COLOUR__|${STATUS_COLOUR}|g" status.html
sed -i -e "s|__SHOW_FOOTER__|${SHOW_FOOTER}|g" status.html
sed -i -e "s/__ONLINE_COUNT__/${ONLINE_COUNT}/g" status.html
sed -i -e "s|__ONLINE_USERS__|${ONLINE_USERS}|g" status.html
sed -i -e "s/__OFFLINE_COUNT__/${OFFLINE_COUNT}/g" status.html
sed -i -e "s|__OFFLINE_USERS__|${OFFLINE_USERS}|g" status.html
sed -i -e "s|__DOMAIN__|${DOMAIN}|g" status.html

aws s3 cp ./status.html "s3://${BUCKET}/status.html"
