#!/bin/sh

set -e

#### get ssh stuff ready

SSH_PATH="$HOME/.ssh"

mkdir "$SSH_PATH"
touch "$SSH_PATH/known_hosts"

echo "$PRIVATE_KEY" > "$SSH_PATH/deploy_key"
echo "$PUBLIC_KEY" > "$SSH_PATH/deploy_key.pub"

chmod 700 "$SSH_PATH"
chmod 600 "$SSH_PATH/known_hosts"
chmod 600 "$SSH_PATH/deploy_key"
chmod 600 "$SSH_PATH/deploy_key.pub"

eval $(ssh-agent)
ssh-add "$SSH_PATH/deploy_key"

mv /known_hosts "$SSH_PATH/known_hosts"

#### deploy to hosts

hosts=(${WEB_HOSTS})
chosts=(${CELERY_HOSTS})
bhosts=(${BEAT_HOSTS})

for h in "${hosts[@]}"
do
    ssh $USER@$h docker pull ${REPOSITORY}thraxil/$APP:$TAG
    ssh $USER@$h cp /var/www/$APP/TAG /var/www/$APP/REVERT || true
    ssh $USER@$h "echo export TAG=$TAG > /var/www/$APP/TAG"
done

for h in "${chosts[@]}"
do
    ssh $USER@$h docker pull ${REPOSITORY}thraxil/$APP:$TAG
    ssh $USER@$h cp /var/www/$APP/TAG /var/www/$APP/REVERT || true
    ssh $USER@$h "echo export TAG=$TAG > /var/www/$APP/TAG"
done

for h in "${bhosts[@]}"
do
    ssh $USER@$h docker pull ${REPOSITORY}thraxil/$APP:$TAG
    ssh $USER@$h cp /var/www/$APP/TAG /var/www/$APP/REVERT || true
    ssh $USER@$h "echo export TAG=$TAG > /var/www/$APP/TAG"
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
COMMIT=$(git log -n 1 --pretty=format:'%H')

curl ${SENTRY_URL} \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\\\"version\\\": \\\"${COMMIT}\\\"}"
