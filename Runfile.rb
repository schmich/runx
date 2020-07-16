def is_vm?
  `whoami`.strip == 'vagrant'
end

def run(command)
  if is_vm?
    system(command) || fail
  else
    system "vagrant ssh -c \"#{command}\""
  end
end

task 'Build runx: linux darwin windows'
def build(*platforms)
  run "cd /src && sudo docker build -t runx . && sudo docker run --rm -v $(pwd):/src runx ruby build.rb #{platforms.join(' ')}"
end

task 'Start Docker shell'
def shell
  run 'cd /src sudo docker build -t runx . && sudo docker run --rm -it -v $(pwd):/src runx /bin/bash'
end
