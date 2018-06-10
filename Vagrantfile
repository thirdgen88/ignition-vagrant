# -*- mode: ruby -*-
# vi: set ft=ruby :

$install = <<SCRIPT
# Initialize install log
rm -f install.log
# Configure for noninteractive mode (for dpkg)
export DEBIAN_FRONTEND=noninteractive
# Prevent accessing stdin when no terminal available in root profile
sudo sed -i 's/^mesg n/tty -s \\&\\& mesg n/g' /root/.profile
sudo ex +"%s@DPkg@//DPkg" -cwq /etc/apt/apt.conf.d/70debconf
sudo dpkg-reconfigure debconf -f noninteractive -p critical
# Update Apt Repositories
sudo apt-get update >> install.log
# Setup Apt Cacher NG
echo "Setting up Package Caching"
sudo apt-get install -y apt-cacher-ng >> install.log
echo $'Acquire::http::Proxy \"http://localhost:3142\";' > /etc/apt/apt.conf.d/00aptproxy
# Apply fix for Oracle Java via the cache - https://askubuntu.com/questions/195297/install-oracle-java7-installer-through-apt-cacher-ng
sudo sed -i '$ a PfilePattern = .*(\\\\.d?deb|\\\\.rpm|\\\\.drpm|\\\\.dsc|\\\\.tar(\\\\.gz|\\\\.bz2|\\\\.lzma|\\\\.xz)(\\\\.gpg|\\\\?AuthParam=.*)?|\\\\.diff(\\\\.gz|\\\\.bz2|\\\\.lzma|\\\\.xz)|\\\\.jigdo|\\\\.template|changelog|copyright|\\\\.udeb|\\\\.debdelta|\\\\.diff/.*\\\\.gz|(Devel)?ReleaseAnnouncement(\\\\?.*)?|[a-f0-9]+-(susedata|updateinfo|primary|deltainfo).xml.gz|fonts/(final/)?[a-z]+32.exe(\\\\?download.*)?|/dists/.*/installer-[^/]+/[0-9][^/]+/images/.*)$' /etc/apt-cacher-ng/acng.conf
sudo sed -i '$ a RequestAppendix: Cookie: oraclelicense=a' /etc/apt-cacher-ng/acng.conf
sudo service apt-cacher-ng stop
# Restore package cache if available
if [ -f /vagrant/package-cache.tar ]; then
  echo "Restoring existing package cache"
  sudo tar vxf /vagrant/package-cache.tar -C /var/cache/apt-cacher-ng >> install.log
fi
echo "Starting Package Caching"
sudo service apt-cacher-ng start
# Add Oracle Java Repository
echo "Adding Oracle Java Repository"
sudo add-apt-repository -y ppa:webupd8team/java >> install.log 2>&1
sudo apt-get update >> install.log
# Setup License Acceptance and install Java8
echo "Installing Oracle Java8"
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
sudo apt-get install -y -q oracle-java8-installer >> install.log
# Setup MySQL Setup and install mysql-server
echo "Installing MySQL"
echo "mysql-server mysql-server/root_password select ignitionsql" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again select ignitionsql" | sudo debconf-set-selections
sudo apt-get install -y -q mysql-server >> install.log
# Modify MySQL Default Configuration to utilize broader bind-to address and reload configuration
sudo sed -i 's/^bind-address.*/bind-address = 0\.0\.0\.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart
# Setup MySQL Username
echo "Setting up 'ignition' database with 'ignition' user and password 'ignition'"
mysql -u root --password=ignitionsql -e "CREATE USER 'ignition'@'%' IDENTIFIED BY 'ignition'; CREATE DATABASE ignition; GRANT ALL PRIVILEGES ON ignition.* to 'ignition'@'%';" >> install.log 2>&1
# Enable Auto Backups
echo "Enabling MySQL Auto-Backups"
debconf-set-selections <<< "postfix postfix/mailname string ubuntu-xenial"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"
sudo apt-get install -y automysqlbackup >> install.log
# Redirect MySQL backups to Vagrant share folder
sudo sed -i 's#^BACKUPDIR=.*#BACKUPDIR=/vagrant/database-backups#' /etc/default/automysqlbackup
# Download Ignition if the installer is not already present (or if md5sum doesn't match)
if [ ! -f /vagrant/Ignition-7.9.8-linux-x64-installer.run ] || [ "`md5sum /vagrant/Ignition-7.9.8-linux-x64-installer.run | cut -c 1-32`" != "92b3fd4de27ea95cdf75f6f91fb813b2" ]; then
  echo "Downloading Ignition 7.9.8"
  wget -q http://files.inductiveautomation.com/release/ia/build7.9.8/20180531-1346/Ignition-7.9.8-linux-x64-installer.run -O /vagrant/Ignition-7.9.8-linux-x64-installer.run >> install.log
else
  echo "Existing Installer Detected, Skipping Download"
fi
echo "Installing Ignition 7.9.8"
chmod a+x /vagrant/Ignition-7.9.8-linux-x64-installer.run
sudo /vagrant/Ignition-7.9.8-linux-x64-installer.run --unattendedmodeui none --mode unattended --prefix /usr/local/share/ignition >> install.log
# Restore base gateway backup (if present)
if [ -f /vagrant/base-gateway.gwbk ]; then
  echo "Restoring Base Gateway Backup"
  sudo /usr/local/share/ignition/gwcmd.sh -s /vagrant/base-gateway.gwbk -y >> install.log
fi
# Enable Module Debugging
sudo sed -r -i 's/^#wrapper\\.java\\.additional\\.([0-9]{1,})=-Xdebug/wrapper.java.additional.\\1=-Xdebug/' /var/lib/ignition/data/ignition.conf
sudo sed -r -i 's/^#wrapper\\.java\\.additional\\.([0-9]{1,})=-Xrunjdwp(.*)/wrapper.java.additional.\\1=-Xrunjdwp\\2/' /var/lib/ignition/data/ignition.conf
# Allow unsigned modules
sudo sed -r -i 's/^wrapper\\.java\\.additional\\.6.*/&\\nwrapper.java.additional.7=-Dia.developer.moduleupload=true/' /var/lib/ignition/data/ignition.conf
sudo sed -r -i 's/^wrapper\\.java\\.additional\\.7.*/&\\nwrapper.java.additional.8=-Dignition.allowunsignedmodules=true/' /var/lib/ignition/data/ignition.conf
# Start Ignition
echo "Starting Ignition"
sudo systemctl start ignition.service
# Preserve Package Caches - Note that simply using a shared folder connection for the apt-cacher-ng service breaks it, so this is the alternative.
echo "Preserving Package Caches"
pushd /var/cache/apt-cacher-ng >> install.log
sudo tar vcf /vagrant/package-cache.tar * >> install.log
popd >> install.log
SCRIPT

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # Ubuntu 18.04 (Bionic Beaver) Box Configuration
  config.vm.box = "ubuntu/bionic64"

  # Ignition
  config.vm.network "forwarded_port", guest: 8088, host: 8088, host_ip: "127.0.0.1"
  # MySQL
  config.vm.network "forwarded_port", guest: 3306, host: 3306, host_ip: "127.0.0.1"
  # Ignition Debugging
  config.vm.network "forwarded_port", guest: 8000, host: 8000, host_ip: "127.0.0.1"

  # Provider-specific configurations
  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.memory = "2048"
  end
  
  config.vm.provider "vmware_fusion" do |vm, override|
    override.vm.box = "bento/ubuntu-18.04"
    vm.linked_clone = true
    vm.vmx["memsize"] = "2048"
  end

  config.vm.provider "vmware_workstation" do |vm, override|
    override.vm.box = "bento/ubuntu-18.04"
    vm.linked_clone = true
    vm.vmx["memsize"] = "2048"
  end

  config.vm.provider "parallels" do |prl, override|
    override.vm.box = "parallels/ubuntu-16.04"
    prl.linked_clone = true
    prl.memory = 2048
  end

  # Enable provisioning with a shell script. 
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
  config.vm.provision "shell", inline: $install
end
