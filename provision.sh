#!/bin/bash

# Update OS packages
sudo aptitude update
sudo DEBIAN_FRONTEND=noninteractive aptitude -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" safe-upgrade

# Install OS packages
sudo add-apt-repository -y ppa:pitti/postgresql
sudo aptitude -y install curl git-core jenkins libpq-dev nginx postgresql python-software-properties ufw virtualenvwrapper vim

# Create PostgreSQL Jenkins user
sudo su postgres -c "createuser jenkins --createdb --no-superuser --no-createrole"
