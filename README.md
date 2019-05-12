A Github Action that I use to deploy my django apps with docker.

Some bits are hard-coded for my setup so I don't recommend using this
directly, but you could certainly fork it and set it up for your environment.

Github secrets that need to be set:

* `WEB_HOSTS` - space separated list of web app servers.
* `CELERY_HOSTS` - (optional) space separated list of hosts running a celery worker
* `BEAT_HOSTS` - (optional) space separated list of hosts running a celery beat worker
* `PRIVATE_KEY` - ssh private key. obviously, you'll need the
  corresponding public key on every server you want to connect to and
  it should be passphrase-less.
* `KNOWN_HOSTS` - contents of an ssh `known_hosts` file. Generate it
  by doing something like `ssh-keyscan -t rsa $HOST >> known_hosts`
  for every host that you are going to connect to. Then paste the
  contents of that file into the Github secret field.

Other Environment variables:

* `SSH_USER` - user to ssh as. This user will need password-less
  `sudo` access on the server for the appropriate `systemctl` commands
  and permissions to interact with docker.
* `APP` - the app it's building/deploying.

Sample Usage:

```
action "deploy" {
  needs = "docker push"
  uses = "thraxil/django-deploy-action@master"
  secrets = [
     "PRIVATE_KEY",
     "KNOWN_HOSTS",
     "WEB_HOSTS",
  ]
  env = {
    SSH_USER = "anders"
    APP = "mithras"
  }
}
```
