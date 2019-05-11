#!/bin/bash

set -e

#### check that we have the vars needed

# GITHUB set ones

if [[ -z "$GITHUB_SHA" ]]; then
	echo "Set the GITHUB_SHA env variable."
	exit 1
fi

# ssh related
if [[ -z "$USER" ]]; then
	echo "Set the USER env variable."
	exit 1
fi
if [[ -z "$PRIVATE_KEY" ]]; then
	echo "Set the PRIVATE_KEY env variable."
	exit 1
fi
if [[ -z "$PUBLIC_KEY" ]]; then
	echo "Set the PUBLIC_KEY env variable."
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
# TODO: make this one optional
if [[ -z "$SENTRY_URL" ]]; then
	echo "Set the SENTRY_URL env variable."
	exit 1
fi


#### get ssh stuff ready

SSH_PATH="$HOME/.ssh"

mkdir "$SSH_PATH"
mv /known_hosts "$SSH_PATH/known_hosts"

echo "$PRIVATE_KEY" > "$SSH_PATH/deploy_key"
echo "$PUBLIC_KEY" > "$SSH_PATH/deploy_key.pub"

chmod 700 "$SSH_PATH"
chmod 600 "$SSH_PATH/known_hosts"
chmod 600 "$SSH_PATH/deploy_key"
chmod 600 "$SSH_PATH/deploy_key.pub"

eval $(ssh-agent)
ssh-add "$SSH_PATH/deploy_key"

#### deploy to hosts

hosts=(${WEB_HOSTS})
chosts=(${CELERY_HOSTS})
bhosts=(${BEAT_HOSTS})

for h in "${hosts[@]}"
do
    ssh $USER@$h docker pull ${REPOSITORY}thraxil/$APP:${GITHUB_SHA}
    ssh $USER@$h cp /var/www/$APP/TAG /var/www/$APP/REVERT || true
    ssh $USER@$h "echo export TAG=${GITHUB_SHA} > /var/www/$APP/TAG"
done

for h in "${chosts[@]}"
do
    ssh $USER@$h docker pull ${REPOSITORY}thraxil/$APP:${GITHUB_SHA}
    ssh $USER@$h cp /var/www/$APP/TAG /var/www/$APP/REVERT || true
    ssh $USER@$h "echo export TAG=${GITHUB_SHA} > /var/www/$APP/TAG"
done

for h in "${bhosts[@]}"
do
    ssh $USER@$h docker pull ${REPOSITORY}thraxil/$APP:${GITHUB_SHA}
    ssh $USER@$h cp /var/www/$APP/TAG /var/www/$APP/REVERT || true
    ssh $USER@$h "echo export TAG=${GITHUB_SHA} > /var/www/$APP/TAG"
done

# run some tasks on just one of the hosts
h=${hosts[0]}

ssh $USER@$h /usr/local/bin/docker-runner $APP migrate
ssh $USER@$h /usr/local/bin/docker-runner $APP collectstatic
ssh $USER@$h /usr/local/bin/docker-runner $APP compress

# restart everything

for h in "${hosts[@]}"
do
    ssh $USER@$h sudo systemctl stop $APP.service || true
    ssh $USER@$h sudo systemctl start $APP.service
done

for h in "${chosts[@]}"
do
    ssh $USER@$h sudo systemctl stop $APP-worker.service || true
    ssh $USER@$h sudo systemctl start $APP-worker.service
done

for h in "${bhosts[@]}"
do
    ssh $USER@$h sudo systemctl stop $APP-beat.service || true
    ssh $USER@$h sudo systemctl start $APP-beat.service
done

# sentry release

curl ${SENTRY_URL} \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\\\"version\\\": \\\"${GITHUB_SHA}\\\"}"
