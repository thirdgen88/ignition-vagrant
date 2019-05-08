#!/bin/bash
set -eo pipefail
shopt -s nullglob

# Inherit incoming or set defaults for environment variables.
# The values for these can be driven by the provisioning section of the Vagrantfile
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-ignitionsql}
MYSQL_DATABASE=${MYSQL_DATABASE:-ignition}
MYSQL_USER=${MYSQL_USER:-ignition}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-ignition}
IGNITION_VERSION="8.0.1"
IGNITION_DOWNLOAD_URL="https://s3.amazonaws.com/files.inductiveautomation.com/release/ia/build8.0.1/20190507-0808/Ignition-8.0.1-linux-x64-installer.run"
IGNITION_DOWNLOAD_SHA256="86ae914b6b2d366319a3fb01bc1ea9c14213383c59d34c38d36b1dba3b531787"
IGNITION_INSTALLER_NAME="Ignition-${IGNITION_VERSION}-linux-x64-installer.run"
IGNITION_STARTUP_DELAY=${IGNITION_STARTUP_DELAY:-90}
GATEWAY_ADMIN_USERNAME=${GATEWAY_ADMIN_USERNAME:-admin}

if [ -z "$GATEWAY_ADMIN_PASSWORD" -a -z "$GATEWAY_RANDOM_ADMIN_PASSWORD" ]; then
    echo >&2 'ERROR: Gateway is not initialized and no password option is specified '
    echo >&2 '  You need to specify either GATEWAY_ADMIN_PASSWORD or GATEWAY_RANDOM_ADMIN_PASSWORD'
    exit 1
fi

# usage: perform_commissioning URL START_FLAG
#   ie: perform_commissioning http://localhost:8088/post-step 1
perform_commissioning() {
    local url="$1"

    # Register EULA Acceptance
    local license_accept_payload='{"id":"license","step":"eula","data":{"accept":true}}'
    curl -H "Content-Type: application/json" -d "${license_accept_payload}" ${url} > /dev/null 2>&1

    # Register Authentication Details
    local auth_user="${GATEWAY_ADMIN_USERNAME:=admin}"
    local auth_salt=$(date +%s | sha256sum | head -c 8)
    local auth_pwhash=$(echo -en ${GATEWAY_ADMIN_PASSWORD}${auth_salt} | sha256sum - | cut -c -64)
    local auth_password="[${auth_salt}]${auth_pwhash}"
    local auth_payload='{"id":"authentication","step":"authSetup","data":{"username":"'${auth_user}'","password":"'${auth_password}'"}}'
    curl -H "Content-Type: application/json" -d "${auth_payload}" ${url} > /dev/null 2>&1

    # Register Port Configuration
    local http_port="${GATEWAY_HTTP_PORT:=8088}"
    local https_port="${GATEWAY_HTTPS_PORT:=8043}"
    local use_ssl="${GATEWAY_USESSL:=false}"
    local port_payload='{"id":"connections","step":"connections","data":{"http":'${http_port}',"https":'${https_port}',"useSSL":'${use_ssl}'}}'
    curl -H "Content-Type: application/json" -d "${port_payload}" ${url} > /dev/null 2>&1

    # Finalize
    if [ "$2" = "1" ]; then
        local start_flag="true"
    else
        local start_flag="false"
    fi
    local finalize_payload='{"id":"finished","data":{"start":'${start_flag}'}}'
    curl -H "Content-Type: application/json" -d "${finalize_payload}" ${url} > /dev/null 2>&1
}

# usage: health_check PHASE_DESC DELAY_SECS
#   ie: health_check "Gateway Commissioning" 60
health_check() {
    local phase="$1"
    local delay=$2

    # Wait for a short period for the commissioning servlet to come alive
    for ((i=${delay};i>0;i--)); do
        if curl -f http://localhost:8088/StatusPing 2>&1 | grep -c RUNNING > /dev/null; then   
            break
        fi
        sleep 1
    done
    if [ "$i" -le 0 ]; then
        echo >&2 "Failed to detect RUNNING status during ${phase} after ${delay} delay."
        exit 1
    fi
}

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
# Install some prerequisite packages
apt-get install -y curl pwgen >> install.log
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
# Download Ignition if the installer is not already present (or if md5sum doesn't match)
if [ ! -f /vagrant/${IGNITION_INSTALLER_NAME} ] || [ "`sha256sum /vagrant/${IGNITION_INSTALLER_NAME} | cut -c 1-64`" != ${IGNITION_DOWNLOAD_SHA256} ]; then
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
sed -r -i 's/^wrapper\.java\.additional\.3.*/&\nwrapper.java.additional.4=-Dia.developer.moduleupload=true/' /var/lib/ignition/data/ignition.conf
sed -r -i 's/^wrapper\.java\.additional\.4.*/&\nwrapper.java.additional.5=-Dignition.allowunsignedmodules=true/' /var/lib/ignition/data/ignition.conf
# Generate Ignition Gateway Random Password if directed
if [ ! -z "$GATEWAY_RANDOM_ADMIN_PASSWORD" ]; then
    export GATEWAY_ADMIN_PASSWORD="$(pwgen -1 32)"
fi
# Start Ignition
echo "Starting Ignition"
systemctl start ignition.service
# Perform System Commissioning
echo "Performing commissioning actions..."
perform_commissioning http://localhost:8088/post-step 1
# Restore base gateway backup (if present)
if [ -f /vagrant/base-gateway.gwbk ]; then
  sleep 5
  echo "Waiting for Gateway Startup to Restore Gateway Backup"
  health_check "Startup" ${IGNITION_STARTUP_DELAY:=120}
  
  echo "Restoring Base Gateway Backup"
  printf '\n' | /usr/local/share/ignition/gwcmd.sh --restore /vagrant/base-gateway.gwbk -y >> install.log

  health_check "Restore" ${IGNITION_STARTUP_DELAY}
  /usr/local/share/ignition/gwcmd.sh -p >> install.log
  systemctl restart ignition.service
  health_check "Recommissioning" 10
  echo "Resetting Gateway Credentials"
  perform_commissioning http://localhost:8088/post-step 1
fi
# Output Credentials
echo "  GATEWAY_ADMIN_USERNAME: ${GATEWAY_ADMIN_USERNAME}"
if [ ! -z "$GATEWAY_RANDOM_ADMIN_PASSWORD" ]; then echo "  GATEWAY_RANDOM_ADMIN_PASSWORD: ${GATEWAY_ADMIN_PASSWORD}"; fi
echo "  GATEWAY_HTTP_PORT: ${GATEWAY_HTTP_PORT}"
echo "  GATEWAY_HTTPS_PORT: ${GATEWAY_HTTPS_PORT}"
# Preserve Package Caches - Note that simply using a shared folder connection for the apt-cacher-ng service breaks it, so this is the alternative.
echo "Preserving Package Caches"
pushd /var/cache/apt-cacher-ng >> install.log
tar vcf /vagrant/package-cache.tar * >> install.log
popd >> install.log
