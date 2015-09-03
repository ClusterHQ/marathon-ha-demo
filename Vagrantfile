# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

# how many slaves do we want
$runner_vms = 2

load './aws_credentials.rb'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.provider :aws do |aws, override|
    inject_aws_credentials(aws, override, "runnerami")
  end

  vms = (1..$runner_vms).map{ |a| "node#{a}" } << 'master'

  vms.each_with_index do |hostname, x|
    config.vm.define vm_name = hostname do |config|
      config.vm.provider :aws do |aws, override|
        inject_aws_instance_name(aws, hostname)
      end

      config.vm.hostname = hostname

      config.vm.provision "file", source: "./install.sh", destination: "/tmp/install.sh"
      config.vm.provision "file", source: "./generatecerts.sh", destination: "/tmp/generatecerts.sh"
    end
  end
end