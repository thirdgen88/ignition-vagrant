#!/bin/bash

# Inherit incoming or set defaults for environment variables.
# The values for these can be driven by the provisioning section of the Vagrantfile
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-ignitionsql}
MYSQL_DATABASE=${MYSQL_DATABASE:-ignition}
MYSQL_USER=${MYSQL_USER:-ignition}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-ignition}
IGNITION_VERSION="7.9.9"
IGNITION_DOWNLOAD_URL="https://s3.amazonaws.com/files.inductiveautomation.com/release/ia/build7.9.9/20180816-1452/Ignition-7.9.9-linux-x64-installer.run"
IGNITION_INSTALLER_NAME="Ignition-${IGNITION_VERSION}-linux-x64-installer.run"
IGNITION_STARTUP_DELAY=${IGNITION_STARTUP_DELAY:-90}

# Initialize install log
rm -f install.log && touch install.log && chown vagrant.vagrant install.log
# Configure for noninteractive mode (for dpkg)
export DEBIAN_FRONTEND=noninteractive
# Prevent accessing stdin when no terminal available in root profile
sed -i 's/^mesg n/tty -s \&\& mesg n/g' /root/.profile
ex +"%s@DPkg@//DPkg" -cwq /etc/apt/apt.conf.d/70debconf
dpkg-reconfigure debconf -f noninteractive -p critical
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
# Add OpenJDK 8 JRE
echo "Installing OpenJDK 8 Java Runtime Environment"
apt-get -y install openjdk-8-jre-headless >> install.log
sed -r -i 's/^(assistive_technologies)/#\1/' /etc/java-8-openjdk/accessibility.properties
# Setup MySQL Setup and install mysql-server
echo "Installing MySQL Database"
echo "mysql-server mysql-server/root_password select ${MYSQL_ROOT_PASSWORD}" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again select ${MYSQL_ROOT_PASSWORD}" | debconf-set-selections
apt-get install -y -q mysql-server >> install.log
# Modify MySQL Default Configuration to utilize broader bind-to address and reload configuration
sed -i 's/^bind-address.*/bind-address = 0\.0\.0\.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
service mysql restart
# Setup MySQL Username and Client Auth
sh -c 'echo "[client]\nuser=root\npassword=${MYSQL_ROOT_PASSWORD}\n"' > ~/.my.cnf
chmod 600 ~/.my.cnf
echo "Setting up '${MYSQL_DATABASE}' database with '${MYSQL_USER}' user and password '${MYSQL_PASSWORD}'"
mysql -e "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}'; CREATE DATABASE ${MYSQL_DATABASE}; GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* to '${MYSQL_USER}'@'%';" >> install.log 2>&1
sh -c 'echo "[client]\nuser=${MYSQL_USER}\npassword=${MYSQL_PASSWORD}\n"' > /home/vagrant/.my.cnf
chmod 600 /home/vagrant/.my.cnf
chown vagrant.vagrant /home/vagrant/.my.cnf
# Enable Auto Backups
echo "Enabling MySQL Auto-Backups"
debconf-set-selections <<< "postfix postfix/mailname string ignition-vagrant"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"
apt-get install -y automysqlbackup >> install.log
# Redirect MySQL backups to Vagrant share folder
sed -i 's#^BACKUPDIR=.*#BACKUPDIR=/vagrant/database-backups#' /etc/default/automysqlbackup
# Download Ignition if the installer is not already present (or if md5sum doesn't match)
if [ ! -f /vagrant/${IGNITION_INSTALLER_NAME} ] || [ "`md5sum /vagrant/${IGNITION_INSTALLER_NAME} | cut -c 1-32`" != "c714d81f2eeb8ad156754732d3345b49" ]; then
  echo "Downloading Ignition ${IGNITION_VERSION}"
  wget -q --referer https://inductiveautomation.com/* ${IGNITION_DOWNLOAD_URL} -O /vagrant/${IGNITION_INSTALLER_NAME} >> install.log
else
  echo "Existing Installer Detected, Skipping Download"
fi
echo "Installing Ignition ${IGNITION_VERSION}"
chmod a+x /vagrant/${IGNITION_INSTALLER_NAME}
/vagrant/${IGNITION_INSTALLER_NAME} --unattendedmodeui none --mode unattended --prefix /usr/local/share/ignition >> install.log
# Enable Module Debugging
sed -r -i 's/^#wrapper\.java\.additional\.([0-9]{1,})=-Xdebug/wrapper.java.additional.\1=-Xdebug/' /var/lib/ignition/data/ignition.conf
sed -r -i 's/^#wrapper\.java\.additional\.([0-9]{1,})=-Xrunjdwp(.*)/wrapper.java.additional.\1=-Xrunjdwp\2/' /var/lib/ignition/data/ignition.conf
# Allow unsigned modules
sed -r -i 's/^wrapper\.java\.additional\.6.*/&\nwrapper.java.additional.7=-Dia.developer.moduleupload=true/' /var/lib/ignition/data/ignition.conf
sed -r -i 's/^wrapper\.java\.additional\.7.*/&\nwrapper.java.additional.8=-Dignition.allowunsignedmodules=true/' /var/lib/ignition/data/ignition.conf
# Start Ignition
echo "Starting Ignition"
systemctl start ignition.service
# Restore base gateway backup (if present)
if [ -f /vagrant/base-gateway.gwbk ]; then
  echo "Waiting for Gateway Startup to Restore Gateway Backup"
  for ((i=${IGNITION_STARTUP_DELAY:-120};i>0;i--)); do
      if curl -f http://localhost:8088/main/StatusPing 2>&1 | grep -c RUNNING > /dev/null; then
          break
      fi
      sleep 1
  done
  if [ "$i" -le 0 ]; then
      echo >&2 "Ignition initialization process failed."
      exit 1
  fi
  
  echo "Restoring Base Gateway Backup"
  /usr/local/share/ignition/gwcmd.sh -s /vagrant/base-gateway.gwbk -y >> install.log
fi
# Preserve Package Caches - Note that simply using a shared folder connection for the apt-cacher-ng service breaks it, so this is the alternative.
echo "Preserving Package Caches"
pushd /var/cache/apt-cacher-ng >> install.log
tar vcf /vagrant/package-cache.tar * >> install.log
popd >> install.log
