#!/bin/bash
set -eo pipefail
shopt -s nullglob

# Initialize install log
rm -f install.log && touch install.log && chown vagrant.vagrant install.log
# Update Apt Repositories
echo "Updating Package Repositories"
apt-get update >> install.log
# Setup Apt Cacher NG
echo "Setting up Package Caching"
apt-get install -y apt-cacher-ng >> install.log
echo $'Acquire::http::Proxy \"http://localhost:3142\";' > /etc/apt/apt.conf.d/00aptproxy
service apt-cacher-ng stop
# Restore package cache if available
if [ -f /vagrant/package-cache.tar ]; then
  echo "Restoring existing package cache"
  tar vxf /vagrant/package-cache.tar -C /var/cache/apt-cacher-ng >> install.log
fi
echo "Starting Package Caching"
service apt-cacher-ng start