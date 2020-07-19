require 'digest'
require 'tmpdir'
require 'set'

def build(platform, package)
  source_dir = Dir.pwd
  puts "Build for #{platform} in #{source_dir}."

  version = `git tag`.lines.last.strip
  if !version
    $stderr.puts 'Version not found.'
    exit 1
  end

  packages_dir = File.join('.build', 'packages')
  if !Dir.exist?(packages_dir)
    system('mkdir', '-p', packages_dir) || fail
  end

  platform_package = File.expand_path(File.join(packages_dir, package))
  if !File.exist?(platform_package)
    puts "Download Ruby #{platform} package."
    system('curl', '-L', '--fail', '-o', platform_package, "https://d6r77u77i8pq3.cloudfront.net/releases/#{package}") || fail
  end

  Dir.mktmpdir do |tmp|
    runtime_dir = File.join(tmp, 'runtime')
    app_dir = File.join(runtime_dir, 'lib', 'app')
    ruby_dir = File.join(runtime_dir, 'lib', 'ruby')
    system('mkdir', '-p', app_dir) || fail
    system('mkdir', '-p', ruby_dir) || fail

    puts 'Extract platform package.'
    system('tar', '-zx', '-C', ruby_dir, '-f', platform_package) || fail

    system('cp', File.join(source_dir, 'runx.rb'), app_dir) || fail
    system('cp', '-R', File.join(source_dir, 'lib'), app_dir) || fail

    puts 'Create bindata bundle.'
    Dir.chdir(tmp) do
      bindata_filename = File.join(source_dir, 'bindata.go')
      system('rm', '-f', bindata_filename) || fail
      system('go-bindata', '-o', bindata_filename, 'runtime/...') || fail
    end
  end

  commit = `git rev-parse HEAD`.strip
  payload_hash = Digest::SHA256.file('bindata.go').hexdigest[0...8]

  output = "runx-#{platform}-x64"
  output += '.exe' if platform == 'windows'

  puts "Build #{output} version #{version}.#{payload_hash}."

  ENV['GOOS'] = platform
  ENV['GOARCH'] = 'amd64'

  system('rm', '-f', output) || fail
  system('go', 'build', '-o', output, '-ldflags', "-w -s -X main.version=#{version} -X main.commit=#{commit} -X main.payloadDir=#{version}.#{payload_hash}") || fail
end

packages = {
  'linux' => 'traveling-ruby-20150210-2.1.5-linux-x86_64.tar.gz',
  'darwin' => 'traveling-ruby-20150210-2.1.5-osx.tar.gz',
  'windows' => 'traveling-ruby-20150210-2.1.5-win32.tar.gz'
}

platforms = ARGV
if platforms.empty?
  $stderr.puts "Specify platforms: #{packages.keys.join(' ')}"
  exit 1
end

unknown = Set.new(platforms) - Set.new(packages.keys)
if unknown.any?
  $stderr.puts "Unknown platforms: #{unknown.to_a.join(' ')}"
  exit 1
end

platforms.each do |platform|
  build(platform, packages[platform])
end

puts 'Done.'
