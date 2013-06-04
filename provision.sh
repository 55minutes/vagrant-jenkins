#!/bin/bash

# Update OS packages
aptitude -q=2 -y update
DEBIAN_FRONTEND=noninteractive aptitude -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" safe-upgrade

# Install OS packages
add-apt-repository -y ppa:pitti/postgresql
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

# Only replace ~/.bashrc if it doesn't already contain "rbenv init"
su -l jenkins -c "grep -qs 'rbenv init' ~/.bashrc || cat /tmp/rbenvrc ~/.bashrc > ~/.bashrc.tmp && mv ~/.bashrc.tmp ~/.bashrc"
