require 'digest'
require 'fileutils'
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

  if !Dir.exist?('packages')
    FileUtils.mkdir_p('packages')
  end

  platform_package = File.expand_path("packages/#{package}")
  if !File.exist?(platform_package)
    puts "Download Ruby #{platform} package."
    system("curl -L --fail -o \"#{platform_package}\" \"https://d6r77u77i8pq3.cloudfront.net/releases/#{package}\"") || fail
  end

  puts 'Create bindata bundle.'
  Dir.mktmpdir do |tmp|
    runtime_dir = File.join(tmp, 'runtime')
    app_dir = File.join(runtime_dir, 'lib', 'app')
    ruby_dir = File.join(runtime_dir, 'lib', 'ruby')
    FileUtils.mkdir_p(app_dir)
    FileUtils.mkdir_p(ruby_dir)

    system("tar -zxv -C \"#{ruby_dir}\" -f \"#{platform_package}\"")

    FileUtils.copy(File.join(source_dir, 'runx.rb'), app_dir)

    puts 'Create bindata bundle.'
    Dir.chdir(tmp) do
      bindata_filename = File.join(source_dir, 'bindata.go')
      system("go-bindata -o \"#{bindata_filename}\" runtime/...") || fail
    end
  end

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
