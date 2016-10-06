# runx

Cross-platform, zero-install, Ruby-based command runner.

## Setup

[Download the zero-install binary](https://github.com/schmich/runx/releases) to a directory on your `PATH`.

## Usage

Create a `Runfile` with your commands:

```ruby
doc 'Start server.'
run :up do
  system 'docker-compose -f services.yml -f env.yml up --build'
end

doc 'Stop server.'
run :down do
  system 'docker-compose -f services.yml -f env.yml down'
end

doc 'Create Laravel migration.'
run 'migrate:make' do |argv|
  system *%w(docker-compose -f services.yml -f env.yml exec app php /src/artisan migrate:make) + argv
end
```

Run `runx` to see available commands:

```
$ runx
Commands:
  up                Start server.
  down              Stop server.
  migrate:make      Create Laravel migration.
```

Run `runx <command>` to run a command:

```
$ runx up
Building app
Step 1 : FROM php:7-fpm-alpine
 ---> a0955c912431
...

$ runx migrate:make create_some_table
Created Migration: 2016_10_06_133147_create_some_table
Generating optimized class loader
```

Parent directories are searched up to the root until a `Runfile` is found.

## How It Works

The Go-built runx binary contains an OS-specific version of [Phusion's Traveling Ruby](https://github.com/phusion/traveling-ruby) runtime,
embedded with [Jim Teeuwen's go-bindata](https://github.com/jteeuwen/go-bindata).
At runtime, the Ruby distribution is extracted to `~/.runx/<hash>`, the runx Ruby library is loaded,
the `Runfile` is parsed, and commands are dispatched.

## License

Copyright &copy; 2016 Chris Schmich  
MIT License. See [LICENSE](LICENSE) for details.
