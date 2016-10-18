#!env ruby

version = `git tag`.lines.last.strip
if !version
  puts 'Version not found.'
  exit 1
end

target = "runx-linux-x64-#{version}"
system('docker build -t runx .')
system('docker run -it runx')
id = `docker ps -l -q`.strip
system("docker cp #{id}:/src/runx ./#{target}")
system("docker rm #{id}")
system("docker run -it --rm -v #{Dir.pwd}/#{target}:/bin/runx golang:1-wheezy bash")
system("docker rmi runx:latest")
