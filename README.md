# runx

Cross-platform, zero-install, Ruby-based task runner.

`runx` enables you to script command-line-friendly tasks in Ruby that you can run across platforms without requiring a Ruby installation.

## Setup

[Download the zero-install binary](https://github.com/schmich/runx/releases) to a directory on your `PATH`.

## Usage

Create a `Runfile` or `Runfile.rb` with your tasks:

```ruby
doc 'Start server.'
run :up do
  system 'docker-compose -f services.yml -f env.yml up --build'
end

doc 'Stop server.'
run :down do
  system 'docker-compose -f services.yml -f env.yml down'
end

doc 'Create database migration.'
run 'migrate:make' do |*args|
  system *%w(docker-compose -f services.yml -f env.yml exec app php /src/artisan migrate:make) + args
end
```

Run `runx` to see available tasks:

```
$ runx
[runx] In /Users/schmich.

Tasks:
  up                Start server.
  down              Stop server.
  migrate:make      Create database migration.
```

Run `runx <task>` to run a task:

```
$ runx up
[runx] In /Users/schmich.
Building app
Step 1 : FROM php:7-fpm-alpine
 ---> a0955c912431
...

$ runx migrate:make create_some_table
[runx] In /Users/schmich/test.
Created Migration: 2016_10_06_133147_create_some_table
Generating optimized class loader
```

## Advanced

The bundled Ruby version is 2.1.5.

Command-line arguments are passed to the task block:

```ruby
run :show do |*args|
  p args
end
```

```
$ runx show abc 123 "quoted arg"
[runx] In /Users/schmich.
["abc", "123", "quoted arg"]
```

A task can be marked as `auto` to automatically run when no task is specified:

```ruby
run :baz do
  puts 'Baz task.'
end

auto
run :quux do
  puts 'Quux task.'
end
```

```
$ runx
[runx] In /Users/schmich.
Quux task.
```

When locating the `Runfile`, directories are searched up to the filesystem root until it's found, so you can invoke `runx` in project subdirectories.

By default, the working directory is set to the `Runfile` directory unless the `dir` attribute is used. `dir :pwd` sets the working directory to the directory where `runx` was invoked:

```ruby
dir :pwd
run :json do |file|
  require 'json'
  puts JSON.pretty_generate(JSON.parse(File.read(file)))
end
```

You can run tasks from other tasks:

```ruby
run :add do |x, y|
  puts x.to_i + y.to_i
end

run :add5 do |x|
  run :add, 5, x
end
```

```
$ runx add 10 20
[runx] In /Users/schmich.
30

$ runx add5 10
[runx] In /Users/schmich.
15
```

## How It Works

The Go-built runx binary contains an OS-specific version of [Phusion's Traveling Ruby](https://github.com/phusion/traveling-ruby) runtime, embedded with [Jim Teeuwen's go-bindata](https://github.com/jteeuwen/go-bindata). At runtime, the Ruby distribution is extracted to `~/.runx/<hash>`, the runx binary spawns `ruby`, which then loads the runx Ruby library, which finally loads the `Runfile` and runs tasks.

## License

Copyright &copy; 2016 Chris Schmich  
MIT License. See [LICENSE](LICENSE) for details.
