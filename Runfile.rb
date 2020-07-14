def is_vm?
  `whoami`.strip == 'vagrant'
end

def run(command)
  if is_vm?
    system command
  else
    system "vagrant ssh -c \"#{command}\""
  end
end

task 'Build runx binary: linux darwin windows'
def build(*platforms)
  run "cd /src && sudo docker build -t runx . && sudo docker run --rm -v $(pwd):/src runx ruby build.rb #{platforms.join(' ')}"
end
