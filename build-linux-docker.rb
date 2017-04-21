#!env ruby

project = 'runx'

version = `git tag`.lines.last.strip
if !version
  puts 'Version not found.'
  exit 1
end

target = "#{project}-linux-x64-#{version}"
system("docker build -t #{project} .") || fail
system("docker run -it #{project}") || fail
id = `docker ps -l -q`.strip
system("docker cp #{id}:/src/#{project} ./#{target}") || fail
system("docker rm #{id}") || fail
system("docker run -it --rm -v #{Dir.pwd}/#{target}:/bin/#{project} golang:latest bash") || fail
system("docker rmi #{project}:latest") || fail
