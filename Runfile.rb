require 'json'

def is_vm?
  `whoami`.strip == 'vagrant'
end

def image_exists?
  `sudo docker images runx --format "{{json .}}"`.lines.any?
end

def ensure_image
  create_image if !image_exists?
end

def create_image
  system('cd /src && sudo docker build -t runx .') || fail
end

def delete_image
  system('sudo docker rmi --force runx') || fail
end

task 'Create & initialize VM for development'
def init
  if is_vm?
    puts 'This should only be run on the host machine.'
    exit 1
  end

  system('vagrant up') || fail
  docker_create
end

task 'Build runx: linux darwin windows'
def build(*platform)
  if is_vm?
    ensure_image
    system("sudo docker run --rm -v /src:/src runx ruby build.rb #{platform.join(' ')}") || fail
  else
    system("vagrant ssh -c \"cd /src && runx build #{platform.join(' ')}\"")
  end
end

task 'Create Docker image'
def docker_create
  if is_vm?
    delete_image
    create_image
  else
    system("vagrant ssh -c \"cd /src && runx docker build\"")
  end
end

task 'Start interactive Docker shell'
def docker_shell
  if is_vm?
    ensure_image
    system('sudo docker run --rm -it -v /src:/src runx /bin/bash')
  else
    system("vagrant ssh -c \"cd /src && runx docker shell\"")
  end
end

task 'Run Docker command'
def docker_run(cmd, *args)
  if is_vm?
    ensure_image
    system("sudo docker run --rm -v /src:/src runx #{cmd} #{args.join(' ')}")
  else
    system("vagrant ssh -c \"cd /src && runx docker run #{cmd} #{args.join(' ')}\"")
  end
end
