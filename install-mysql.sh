#!/bin/bash
set -eo pipefail
shopt -s nullglob

# Inherit incoming or set defaults for environment variables.
# The values for these can be driven by the provisioning section of the Vagrantfile
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-ignitionsql}
MYSQL_DATABASE=${MYSQL_DATABASE:-ignition}
MYSQL_USER=${MYSQL_USER:-ignition}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-ignition}

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
echo "  MYSQL_DATABASE: ${MYSQL_DATABASE}"
echo "  MYSQL_USER: ${MYSQL_USER}"
echo "  MYSQL_PASSWORD: ${MYSQL_PASSWORD}"
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
