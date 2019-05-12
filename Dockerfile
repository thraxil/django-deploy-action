FROM debian:stable-slim

LABEL "name"="django-deploy"
LABEL "maintainer"="Anders Pearson <anders@thraxil.org>"
LABEL "version"="1.0.0"

LABEL "com.github.actions.name"="Deploy Django"
LABEL "com.github.actions.description"="deploy django app (packed as docker image)"
LABEL "com.github.actions.icon"="chevrons-right"
LABEL "com.github.actions.color"="red"

RUN apt-get update && apt-get install -y \
  openssh-client && \
  rm -Rf /var/lib/apt/lists/*

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
