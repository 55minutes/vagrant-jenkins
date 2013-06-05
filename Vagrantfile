# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

secrets = YAML.load_file('secrets.yml')

# TODO: Specify additional DO SSH keys to be installed
Vagrant.configure("2") do |config|
  config.vm.box = "digital_ocean"
  config.vm.box_url = "https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box"
  config.vm.synced_folder '.', '/vagrant', disabled: true
  config.vm.provision :shell, :path => "provision.sh"

  config.vm.define :ci do |host|
    host.vm.hostname = "ci.55minutes.com"
  end

  config.vm.define :test do |host|
    host.vm.hostname = "test.ci.55minutes.com"
  end

  config.ssh.private_key_path = secrets['ssh_private_key_path']
  config.ssh.username = "jenkins"

  config.vm.provider :digital_ocean do |provider|
    provider.client_id = secrets['digital_ocean_client_id']
    provider.api_key = secrets['digital_ocean_api_key']
    provider.image = "Ubuntu 12.04 x32 Server"
    provider.size = "512MB"
    provider.region = "San Francisco 1"
    provider.ssh_key_name = secrets['digital_ocean_ssh_key_name'] || "#{ENV['USER']}"
    provider.ca_path = secrets['ssl_ca_path'] || 
      "/usr/local/opt/curl-ca-bundle/share/ca-bundle.crt"
  end
end
