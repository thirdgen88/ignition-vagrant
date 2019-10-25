# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # Ubuntu 18.04 (Bionic Beaver) Box Configuration
  config.vm.box = "ubuntu/bionic64"
  config.vm.define "ignition"
  config.vm.hostname = "ignition-vagrant"

  # Initialize Provisioning
  config.vm.provision "initialize", type: "shell", path: "initialize.sh", env: {
    "DEBIAN_FRONTEND" => "noninteractive"
  }

  # Ignition
  config.vm.network "forwarded_port", guest: 8088, host: 8088, host_ip: "127.0.0.1"
  # MySQL
  config.vm.network "forwarded_port", guest: 3306, host: 3306, host_ip: "127.0.0.1"
  # Ignition Debugging
  config.vm.network "forwarded_port", guest: 8000, host: 8000, host_ip: "127.0.0.1"

  # Provider-specific configurations
  config.vm.provider "virtualbox" do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.cpus = 2
  end
  
  config.vm.provider "vmware_desktop" do |vm, override|
    override.vm.box = "bento/ubuntu-18.04"
    vm.vmx["ethernet0.pcislotnumber"] = "32"
    vm.vmx["memsize"] = "2048"
    vm.vmx["numvcpus"] = "2"
  end

  config.vm.provider "parallels" do |prl, override|
    override.vm.box = "parallels/ubuntu-16.04"
    prl.linked_clone = true
    prl.memory = 2048
    prl.cpus = 2
  end

  # Enable provisioning with a series of bash shell scripts. 
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
  config.vm.provision "install-mysql", type: "shell", path: "install-mysql.sh", env: {
    "DEBIAN_FRONTEND" => "noninteractive",
    "MYSQL_ROOT_PASSWORD" => "ignitionsql",
    "MYSQL_DATABASE" => "ignition",
    "MYSQL_USER" => "ignition",
    "MYSQL_PASSWORD" => "ignition"
  }
  config.vm.provision "install-ignition", type: "shell", path: "install-ignition.sh", env: {
    "DEBIAN_FRONTEND" => "noninteractive",
    "GATEWAY_ADMIN_USERNAME" => "admin",
    #"GATEWAY_ADMIN_PASSWORD" => "password",  # define a password for commissioning here ...
    "GATEWAY_RANDOM_ADMIN_PASSWORD" => "1"  # ... or have a random password generated on startup
  }
  config.vm.provision "provision-mysql", type: "shell", path: "provision-mysql.sh"
  config.vm.provision "finalize", type: "shell", path: "finalize.sh", env: {
    "SET_TIMEZONE" => "US/Central"  # US/Pacific, US/Mountain, US/Central, US/Eastern, etc
  }
end
