require 'digest'
require 'fileutils'
require 'tmpdir'
require 'set'

def build(platform, package)
  puts "Build for #{platform}."

  version = `git tag`.lines.last.strip
  if !version
    $stderr.puts 'Version not found.'
    exit 1
  end

  runtime_dir = "runtimes/#{platform}/runtime"
  if !Dir.exist?(runtime_dir)
    FileUtils.mkdir_p("#{runtime_dir}/lib/app")

    Dir.mktmpdir do |tmp|
      tmp = File.join(tmp, 'ruby')
      FileUtils.mkdir_p(tmp)
      system("curl -L --fail \"https://d6r77u77i8pq3.cloudfront.net/releases/#{package}\" | tar -zxv -C #{tmp}") || fail
      system("cp -R --dereference #{tmp} #{runtime_dir}/lib") || fail
    end
  end

  puts 'Create bindata bundle.'
  FileUtils.copy('runx.rb', "#{runtime_dir}/lib/app/runx.rb")
  system("cd runtimes/#{platform} && go-bindata -o ../../bindata.go runtime/...") || fail

  commit = `git rev-parse HEAD`.strip
  payload_hash = Digest::SHA256.file('bindata.go').hexdigest[0...8]

  output = "runx-#{platform}-x64"
  output += '.exe' if platform == 'windows'

  puts "Build #{output} version #{version}.#{payload_hash}."

  ENV['GOOS'] = platform
  ENV['GOARCH'] = 'amd64'

  system("go build -ldflags \"-w -s -X main.version=#{version} -X main.commit=#{commit} -X main.payloadDir=#{version}.#{payload_hash}\" -o #{output}") || fail
end

packages = {
  'linux' => 'traveling-ruby-20150210-2.1.5-linux-x86_64.tar.gz',
  'darwin' => 'traveling-ruby-20150210-2.1.5-osx.tar.gz',
  'windows' => 'traveling-ruby-20150210-2.1.5-win32.tar.gz'
}

platforms = ARGV
if platforms.empty?
  $stderr.puts "Specify platform(s): #{packages.keys.join(' ')}"
  exit 1
end

unknown = Set.new(platforms) - Set.new(packages.keys)
if unknown.any?
  $stderr.puts "Unknown platform(s): #{unknown.to_a.join(' ')}"
  exit 1
end

platforms.each do |platform|
  build(platform, packages[platform])
end

puts 'Done.'
