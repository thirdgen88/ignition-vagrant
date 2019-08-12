#!/bin/bash
set -eo pipefail
shopt -s nullglob

# Set Timezone
if [ ! -z "${SET_TIMEZONE:-}" ]; then
    echo "Setting Timezone: ${SET_TIMEZONE}"
    timedatectl set-timezone ${SET_TIMEZONE}
fi

# Preserve Package Caches - Note that simply using a shared folder connection for the apt-cacher-ng service breaks it, so this is the alternative.
echo "Preserving Package Caches"
pushd /var/cache/apt-cacher-ng >> install.log
tar vcf /vagrant/package-cache.tar * >> install.log
popd >> install.log
