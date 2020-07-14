require 'tmpdir'

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu/xenial64'
  config.vm.hostname = 'runx'

  config.vm.provision 'shell', inline: <<-SCRIPT
    sudo apt-get update
    sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      software-properties-common

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"

    sudo apt-get update
    sudo apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io

    echo 'cd /src' >> ~vagrant/.bashrc
SCRIPT

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = '2048'

    # Move VM host log output to temp dir.
    vb.customize ['modifyvm', :id, '--uartmode1', 'file', File.join(Dir.tmpdir, 'vb')]
  end

  config.vm.synced_folder '.', '/src', mount_options: ['dmode=775,fmode=664']

  config.vm.network :public_network
  config.vm.network :private_network, ip: '10.0.0.20'
end
