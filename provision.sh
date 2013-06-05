#!/bin/bash

# OS packages

## Add repositories
add-apt-repository -y ppa:pitti/postgresql
wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list

## Update OS packages
aptitude -q=2 -y update
DEBIAN_FRONTEND=noninteractive aptitude -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" safe-upgrade

## Install OS packages
aptitude -y install curl git-core jenkins libpq-dev nginx postgresql python-software-properties ufw virtualenvwrapper vim


# Create PostgreSQL Jenkins user
su -l postgres -c "createuser jenkins --createdb --no-superuser --no-createrole"


# Install rbenv
aptitude -y install git-core
su -l jenkins -c "curl -L https://raw.github.com/fesplugas/rbenv-installer/master/bin/rbenv-installer | bash"

bashrc=$(cat <<'EOF'
if [ -d $HOME/.rbenv ]; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
fi
EOF
)
echo "$bashrc" > /tmp/rbenvrc

## Only replace ~/.bashrc if it doesn't already contain "rbenv init"
su -l jenkins -c "grep -qs 'rbenv init' ~/.bashrc || (cat /tmp/rbenvrc ~/.bashrc > ~/.bashrc.tmp && mv ~/.bashrc.tmp ~/.bashrc)"


# Update Jenkins plugins
jenkins_url=http://localhost:8080
cli_jar=/tmp/jenkins-cli.jar
jenkins_cli="java -jar $cli_jar -s $jenkins_url"

## Update the update center
curl -L http://updates.jenkins-ci.org/update-center.json | sed '1d;$d' | curl -X POST -H 'Accept: application/json' -d @- $jenkins_url/updateCenter/byId/default/postBack

## Download the CLI tool
curl -L $jenkins_url/jnlpJars/jenkins-cli.jar -o $cli_jar

## Install the plugins
plugins=( git "github-oauth" campfire brakeman analysis-core)
for plugin in "${plugins[@]}"; do
  $jenkins_cli install-plugin "$plugin"
done

## Restart
$jenkins_cli safe-restart


## Nginx configuration
jenkins=$(cat <<'EOF'
upstream app_server {
    server 127.0.0.1:8080 fail_timeout=0;
}

server {
    listen 80;
    listen [::]:80 default ipv6only=on;
    server_name ci.55minutes.com;

    location / {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;

        if (!-f $request_filename) {
            proxy_pass http://app_server;
            break;
        }
    }
}
EOF
)
echo "$jenkins" > /etc/nginx/sites-available/jenkins
ln -s -f /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
service nginx restart
