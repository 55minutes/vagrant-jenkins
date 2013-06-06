#!/bin/bash

###############
# OS packages #

## Add repositories
add-apt-repository -y ppa:pitti/postgresql
add-apt-repository -y ppa:chris-lea/node.js
wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list

## Update OS packages
aptitude -q=2 -y update
DEBIAN_FRONTEND=noninteractive aptitude -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" safe-upgrade

## Install OS packages
aptitude -y install curl debian-goodies git-core imagemagick jenkins libicu48 libmagickcore-dev libmagickwand-dev libpq-dev libqtwebkit-dev nginx nodejs postgresql python-software-properties ufw vim virtualenvwrapper xvfb


####################
# Generate SSH key #
if [ ! -f ~jenkins/.ssh/id_rsa ]; then
  su -l jenkins -c "mdkir -p ~/.ssh"
  su -l jenkins -c "chmod 700 ~/.ssh"
  su -l jenkins -c "ssh-keygen -t rsa -C "ci.55minutes.com" -f ~/.ssh/id_rsa -P ''"
fi


#################
# Install rbenv #
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

## Boostrap rbenv
~jenkins/.rbenv/plugins/rbenv-bootstrap/bin/rbenv-bootstrap-ubuntu-12-04


##################################
# Create PostgreSQL Jenkins user #
if ! su -l postgres -c "psql -c '\du' | grep -q jenkins"; then
  su -l postgres -c "createuser jenkins --createdb --no-superuser --no-createrole"
fi


##########################
# Update Jenkins plugins #
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


#######################
# Nginx configuration #

## Self signed SSL
cn=ci.55minutes.com
ssl_dir=/etc/ssl
ssl_key=$ssl_dir/${cn}.key
ssl_crt=$ssl_dir/${cn}.crt
if ! [ -f $ssl_key -a -f $ssl_crt ]; then
  openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Albany/O=55 Minutes/CN=${cn}" -keyout $ssl_key -out $ssl_crt
fi

## conf.d
jenkins=$(cat <<'EOF'
upstream jenkins {
    server 127.0.0.1:8080 fail_timeout=0;
}

server {
    listen 80 default;
    listen [::]:80 ipv6only=on;
    server_name ci.55minutes.com;

    rewrite ^ https://$server_name$request_uri? permanent;
}

server {
    listen 443 default ssl;
    listen [::]:443 ipv6only=on;
    server_name ci.55minutes.com;

    ssl_certificate         /etc/ssl/ci.55minutes.com.crt;
    ssl_certificate_key     /etc/ssl/ci.55minutes.com.key;

    # Enable SSL session cache
    ssl_session_cache       shared:SSL:10m;
    ssl_session_timeout     5m;

    # Only accept strong ciphers, but disable the weaker ADH and MD5 ciphers
    ssl_ciphers             HIGH:!ADH:!MD5;
    ssl_prefer_server_ciphers on;

    # Enable STS, http://8n.href.be/
    add_header              Strict-Transport-Security max-age=500;

    # Allow nginx to let .crumb headers pass through for CSRF protection
    # See http://goo.gl/vbpfA
    ignore_invalid_headers off;

    location / {
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;  
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_redirect http:// https://;

        if (!-f $request_filename) {
            proxy_pass http://jenkins;
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


#####################
# ufw configuration #
services=( ssh http https )

sudo ufw disable
ufw default deny
for service in "${services[@]}"; do
  ufw allow $service
done
yes | ufw enable
