#!/bin/bash

set -e

#### check that we have the vars needed

# GITHUB set ones

if [[ -z "$GITHUB_SHA" ]]; then
  echo "Set the GITHUB_SHA env variable."
  exit 1
fi

# ssh related
if [[ -z "$SSH_USER" ]]; then
  # probably not ssh-ing as root
  echo "Set the SSH_USER env variable."
  exit 1
fi
if [[ -z "$PRIVATE_KEY" ]]; then
  echo "Set the PRIVATE_KEY env variable."
  exit 1
fi
if [[ -z "$KNOWN_HOSTS" ]]; then
  echo "Set the KNOWN_HOSTS env variable."
  exit 1
fi

# others
if [[ -z "$APP" ]]; then
  echo "Set the APP env variable."
  exit 1
fi
if [[ -z "$WEB_HOSTS" ]]; then
  echo "Set the WEB_HOSTS env variable."
  exit 1
fi

#### get ssh stuff ready

SSH_PATH="/root/.ssh"

mkdir "$SSH_PATH"

echo "$KNOWN_HOSTS" > "$SSH_PATH/known_hosts"
echo "$PRIVATE_KEY" > "$SSH_PATH/deploy_key"

chmod 700 "$SSH_PATH"
chmod 600 "$SSH_PATH/known_hosts"
chmod 600 "$SSH_PATH/deploy_key"

ssh_cmd="ssh -i $SSH_PATH/deploy_key"

#### deploy to hosts

# all of them (unique) in one list
hosts=($(echo "${WEB_HOSTS} ${CELERY_HOSTS} ${BEAT_HOSTS}" | tr ' ' '\n' | sort -u))
whosts=(${WEB_HOSTS})
chosts=(${CELERY_HOSTS})
bhosts=(${BEAT_HOSTS})

echo "WEB_HOSTS: ${WEB_HOSTS}"
echo "CHOSTS: ${CELERY_HOSTS}"
echo "BHOSTS: ${BEAT_HOSTS}"
echo "all hosts: ${hosts}"

for h in "${hosts[@]}"
do
    echo "pulling and updating tag on $h to ${GITHUB_SHA}"
    $ssh_cmd $SSH_USER@$h docker pull ${REPOSITORY}thraxil/$APP:${GITHUB_SHA}
    $ssh_cmd $SSH_USER@$h cp /var/www/$APP/TAG /var/www/$APP/REVERT || true
    $ssh_cmd $SSH_USER@$h "echo export TAG=${GITHUB_SHA} > /var/www/$APP/TAG"
done

# run some tasks on just one of the hosts
h=${hosts[0]}

$ssh_cmd $SSH_USER@$h /usr/local/bin/docker-runner $APP migrate
$ssh_cmd $SSH_USER@$h /usr/local/bin/docker-runner $APP collectstatic
$ssh_cmd $SSH_USER@$h /usr/local/bin/docker-runner $APP compress

# restart everything

for h in "${whosts[@]}"
do
    echo "restarting gunicorn on $h"
    $ssh_cmd $SSH_USER@$h sudo systemctl stop $APP.service || true
    $ssh_cmd $SSH_USER@$h sudo systemctl start $APP.service
done

for h in "${chosts[@]}"
do
    echo "restarting celery worker on $h"
    $ssh_cmd $SSH_USER@$h sudo systemctl stop $APP-worker.service || true
    $ssh_cmd $SSH_USER@$h sudo systemctl start $APP-worker.service
done

for h in "${bhosts[@]}"
do
    echo "restarting celery beat on $h"
    $ssh_cmd $SSH_USER@$h sudo systemctl stop $APP-beat.service || true
    $ssh_cmd $SSH_USER@$h sudo systemctl start $APP-beat.service
done
