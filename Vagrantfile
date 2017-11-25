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
if [ ! -f /vagrant/Ignition-7.9.5-linux-x64-installer.run ] || [ "`md5sum /vagrant/Ignition-7.9.5-linux-x64-installer.run | cut -c 1-32`" != "6fb4245cccea2f2b004bca7ca371046e" ]; then
  echo "Downloading Ignition 7.9.5"
  wget -q https://s3.amazonaws.com/files.inductiveautomation.com/release/ia/build7.9.5/20171116-1516/Ignition-7.9.5-linux-x64-installer.run -O /vagrant/Ignition-7.9.5-linux-x64-installer.run >> install.log
else
  echo "Existing Installer Detected, Skipping Download"
fi
echo "Installing Ignition 7.9.5"
chmod a+x /vagrant/Ignition-7.9.5-linux-x64-installer.run
sudo /vagrant/Ignition-7.9.5-linux-x64-installer.run --unattendedmodeui none --mode unattended --prefix /usr/local/share/ignition >> install.log
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
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "ubuntu/xenial64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.

  # Ignition
  config.vm.network "forwarded_port", guest: 8088, host: 8088, host_ip: "127.0.0.1"
  # MySQL
  config.vm.network "forwarded_port", guest: 3306, host: 3306, host_ip: "127.0.0.1"
  # Ignition Debugging
  config.vm.network "forwarded_port", guest: 8000, host: 8000, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.
  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.memory = "2048"
  end

  config.vm.provider "parallels" do |prl, override|
    override.vm.box = "parallels/ubuntu-16.04"
    prl.linked_clone = true
    prl.memory = 2048
  end

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
  config.vm.provision "shell", inline: $install
end
