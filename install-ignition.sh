#!/bin/bash
set -eo pipefail
shopt -s nullglob

# Inherit incoming or set defaults for environment variables.
# The values for these can be driven by the provisioning section of the Vagrantfile
IGNITION_VERSION="8.0.2"
IGNITION_DOWNLOAD_URL="https://files.inductiveautomation.com/release/ia/build8.0.2/20190605-1127/Ignition-8.0.2-linux-x64-installer.run"
IGNITION_DOWNLOAD_SHA256="101aee71febf0f306bb5889ed5cca9d1836fd140e2379f9723dd161646ddae2e"
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

# Install some prerequisite packages
apt-get install -y curl pwgen >> install.log
# Download Ignition if the installer is not already present (or if md5sum doesn't match)
if [ ! -f /vagrant/${IGNITION_INSTALLER_NAME} ] || [ "`sha256sum /vagrant/${IGNITION_INSTALLER_NAME} | cut -c 1-64`" != ${IGNITION_DOWNLOAD_SHA256} ]; then
  echo "Downloading Ignition ${IGNITION_VERSION}"
  wget -q --referer "https://inductiveautomation.com/*" ${IGNITION_DOWNLOAD_URL} -O /vagrant/${IGNITION_INSTALLER_NAME} >> install.log
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
echo "Waiting for commissioning servlet to become active..."
health_check "Commissioning Phase" 10
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