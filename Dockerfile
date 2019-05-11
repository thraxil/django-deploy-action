FROM debian:stable-slim

RUN apt-get update && apt-get install -y \
  openssh-client && \
  rm -Rf /var/lib/apt/lists/*

ADD entrypoint.sh /entrypoint.sh
ADD known_hosts /known_hosts

ENTRYPOINT ["/entrypoint.sh"]
