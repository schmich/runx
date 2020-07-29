$:.unshift(File.join(__dir__, 'lib'))

require 'colorize'
require 'io/console'
require 'pathname'
require 'set'

$__main__ = self

module Runx
  class RunxError < StandardError
    def initialize(message)
      super(message)
    end
  end

  class Task
    def initialize(method, description, dir, source)
      @name = method.name.to_s.gsub(/_+/, ' ').strip
      @method = method
      @arguments = TaskArguments.new(method)
      @description = description
      @dir = dir
      @source = source
    end

    def run(args, &block)
      begin
        if !Dir.exist?(@dir)
          raise RunxError.new("directory not found: #{@dir}")
        end

        task_args = @arguments.from_cli(args)
        Dir.chdir(@dir) do
          $stderr.puts "[runx] in #{@dir}"
          @method.call(*task_args, &block)
        end
      rescue RunxError => e
        raise RunxError.new("in task #{@name.cyan}: #{e}")
      end
    end

    attr_reader :name, :method, :arguments, :description, :source
  end

  class TaskArguments
    def initialize(method)
      @method = method
    end

    def from_cli(args)
      params_type = { req: [], opt: [], rest: [], keyreq: [], key: [], keyrest: [] }.merge(Hash[
        @method.parameters
               .group_by(&:first)
               .map { |type, params| [type, params.map(&:last)] }
      ])

      has_rest = params_type[:rest].any?
      has_keyrest = params_type[:keyrest].any?

      keys = params_type[:key] + params_type[:keyreq]

      positional = []
      keyed = {}
      key = nil

      # If a keyed argument is seen multiple times, map it to an array of values.
      # '--opt a' becomes { opt: 'a' }
      # '--opt a --opt b' becomes { opt: ['a', 'b'] }
      add_keyed_value = proc { |key, value|
        existing = keyed[key]
        if existing.nil?
          keyed[key] = value
        elsif existing.is_a?(Array)
          keyed[key] << value
        else
          keyed[key] = [existing, value]
        end
      }

      args.each do |arg|
        if key
          add_keyed_value.call(key, arg)
          key = nil
        elsif arg =~ /^--?(.+?)(=(.*))?$/
          name = $1
          value = $3
          key = name_key(name)
          if !keys.include?(key) && !has_rest && !has_keyrest
            raise RunxError.new("invalid option --#{name}")
          end

          if value
            add_keyed_value.call(key, value)
            key = nil
          end
        else
          positional << arg
        end
      end

      # Handle trailing options with no value.
      if key
        add_keyed_value.call(key, '')
        key = nil
      end

      req_count = params_type[:req].count
      opt_count = params_type[:opt].count

      if positional.count < req_count
        required = params_type[:req].drop(positional.count).map { |arg| positional_name(arg) }.join(' ')
        raise RunxError.new("missing required arguments: #{required}")
      end

      max_positional = req_count + opt_count
      if positional.count > max_positional && !has_rest
        raise RunxError.new("too many arguments: given #{positional.count}, max #{max_positional}")
      end

      required_keys = params_type[:keyreq]
      missing_keys = required_keys - keyed.keys

      if missing_keys.any?
        required = missing_keys.map { |key| "--#{key_name(key)}" }.join(' ')
        raise RunxError.new("missing required options: #{required}")
      end

      if keyed.empty?
        positional
      else
        positional + [keyed]
      end
    end

    def to_s
      @method.parameters.map { |type, sym|
        if type == :req
          positional_name(sym)
        elsif type == :opt
          "[#{positional_name(sym)}]"
        elsif type == :rest
          "[#{positional_name(sym)}...]"
        elsif type == :keyreq
          "--#{key_name(sym)} VALUE"
        elsif type == :key
          "[--#{key_name(sym)} VALUE]"
        elsif type == :keyrest
          "[--NAME VALUE...]"
        end
      }.join(' ')
    end

    private

    def positional_name(arg)
      arg.to_s.upcase
    end

    def key_name(key)
      key.to_s.gsub('_', '-')
    end

    def name_key(name)
      name.gsub('-', '_').to_sym
    end
  end

  class SourceLocation
    def initialize(filename, line_number)
      @filename = filename.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
      @line_number = line_number
    end

    def self.from_frame(frame)
      if frame =~ /^(.*?):(\d+)/
        SourceLocation.new($1, $2.to_i)
      elsif frame =~ /^(.*?):/
        SourceLocation.new($1, nil)
      else
        SourceLocation.new(nil, nil)
      end
    end

    def to_s
      if @filename
        if @line_number
          "#{@filename}:#{@line_number}"
        else
          @filename
        end
      else
        '(unknown)'
      end
    end

    attr_reader :filename, :line_number
  end

  class Import
    def initialize(dir, source)
      @absolute_dir = File.expand_path(dir).gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
      @source = source
    end

    attr_reader :absolute_dir, :source
  end

  class TaskManager
    def initialize
      @runfiles = {}
      @filenames_seen = Set.new
      @tasks = {}
      @imports = []
      @common_dir_prefix = nil

      @on_import = nil
      @on_task = nil
      @on_method_added = nil
    end

    def load(filename)
      load_runfile(filename)
      while @imports.any?
        import = @imports.shift
        begin
          filename = Runx.runfile_path(import.absolute_dir)
          load_runfile(filename)
        rescue RunxError => e
          raise RunxError.new("import from #{import.source}: #{e}")
        end
      end

      @runfiles.values.flatten.each do |task|
        dup = @tasks[task.name]
        if !dup.nil?
          raise RunxError.new("duplicate task #{task.name.cyan} defined at #{dup.source} and #{task.source}")
        end

        @tasks[task.name] = task
      end

      if @tasks.empty?
        raise RunxError.new('no tasks defined, see https://github.com/schmich/runx#usage')
      end

      dirs = @filenames_seen.map { |path| File.dirname(path) }
      @common_dir_prefix = common_dir_prefix(dirs)
    end

    def show_help
      $stderr.puts 'Tasks:'

      multifile = @runfiles.values.count > 1
      task_leader = multifile ? '    ' : '  '

      # Some consoles won't let you print on the last column without
      # an extra newline, so we avoid the last column entirely.
      _, console_width = IO.console.winsize
      console_width -= 1

      args = Hash[@tasks.values.map { |task|
        [task, task.arguments.to_s]
      }]

      make_title = proc { |task, colorize|
        name = colorize ? task.name.cyan : task.name
        [name, args[task]].reject(&:empty?).join(' ')
      }

      task_width = @tasks.values.map { |task| make_title.call(task, false).length }.max
      task_pad = 5

      description_width = console_width - task_leader.length - task_width - task_pad
      description_leader = ' ' * (task_leader.length + task_width + task_pad)

      @runfiles.each do |filename, tasks|
        next if tasks.empty?

        $stderr.puts
        if multifile
          $stderr.puts "  #{relative_path(filename)}"
          $stderr.puts
        end

        tasks.each do |task|
          space = ' ' * (task_width - (make_title.call(task, false).length) + task_pad)
          $stderr.print "#{task_leader}#{make_title.call(task, true)}#{space}"

          description_lines = word_wrap(task.description, description_width)
          0.upto(description_lines.count - 1) do |i|
            $stderr.print description_leader if i > 0
            $stderr.puts description_lines[i]
          end
        end
      end

      $stderr.puts
    end

    def run_task(args)
      # Because task methods have underscores mapped to spaces for ergonomics (e.g. 'foo_bar' becomes 'foo bar')
      # *and* because we allow command-line arguments, determining which task to run can be ambiguous.
      # Here, we take the approach of running the task with the longest matching name. We try to find a
      # matching task using all args. If no matching task is found, we move the last arg onto the list of
      # arguments passed to the task and repeat this process with the new, shorter task name.

      tasks = Hash[@tasks.map { |name, task| [name.split(' '), task] }]

      task_args = []
      while !args.empty?
        task = tasks[args]
        if task
          return task.run(task_args)
        end

        task_args.unshift(args.pop)
      end

      # No more args and we never matched a task name.
      raise RunxError.new('invalid task')
    end

    def on_task(description, source)
      @on_task.call(description, source)
    end

    def on_import(dir, source)
      @on_import.call(dir, source)
    end

    def on_method_added(method, source)
      @on_method_added.call(method, source)
    end

    private

    def word_wrap(string, width)
      lines = string.split("\n").flat_map { |part| word_wrap_line(part, width) }
      return lines.empty? ? [''] : lines
    end

    def word_wrap_line(string, width)
      return [string] if string.length <= width
      index = string.rindex(/\s/, width) || width
      left, right = string[0...index], string[index...string.length].lstrip
      return [left] + word_wrap_line(right, width)
    end

    def common_dir_prefix(dirs)
      dirs.map { |dir|
        paths = []
        Pathname.new(dir).cleanpath.ascend { |path| paths << path }
        paths.reverse
      }.reduce { |acc, cur|
        acc.zip(cur).take_while { |l, r| l == r }.map(&:first)
      }.last.to_s
    end

    def relative_path(path)
      relative_path = Pathname.new(File.dirname(path)).relative_path_from(Pathname.new(@common_dir_prefix)).to_s
      relative_path = '' if relative_path == '.'

      common_parent = File.basename(@common_dir_prefix)
      return Pathname.new(File.join(common_parent, relative_path))
        .cleanpath.to_s
        .gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
    end

    def load_runfile(filename)
      if !File.exist?(filename)
        raise RunxError.new("#{filename} not found")
      end

      absolute_filename = File.expand_path(filename).gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
      absolute_dir = File.dirname(absolute_filename)

      # Do not load the same file twice.
      return if !@filenames_seen.add?(absolute_filename)

      task_source = nil
      description = nil

      @on_task = lambda do |task_description, source|
        if !task_source.nil?
          raise RunxError.new("task declared with no implementing method at #{task_source}")
        end

        task_source = source
        description = task_description
      end

      @on_import = lambda do |dir, source|
        @imports << Import.new(dir, source)
      end

      @on_method_added = lambda do |method, source|
        return if task_source.nil?
        task_source = nil
        @runfiles[absolute_filename] ||= []
        @runfiles[absolute_filename] << Task.new(method, description, absolute_dir, source)
      end

      Dir.chdir(absolute_dir) do
        require(absolute_filename)
      end
    end
  end

  class << self
    def runfile_path(dir)
      File.join(dir, 'Runfile.rb').gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
    end

    def load(runfile)
      manager = TaskManager.new
      context = $__main__

      context.send(:define_method, :import) do |dir|
        source = SourceLocation.from_frame(caller(1).first)
        manager.on_import(dir, source)
      end

      context.send(:define_method, :task) do |description = ''|
        source = SourceLocation.from_frame(caller(1).first)
        manager.on_task(description, source)
      end

      context.class.define_singleton_method(:method_added) do |id|
        return if self != context.class
        source = SourceLocation.from_frame(caller(1).first)
        manager.on_method_added(method(id), source)
      end

      manager.load(runfile)
      manager
    end
  end
end

return unless __FILE__ == $0

begin
  find_runfile = lambda do
    Pathname.getwd.ascend do |dir|
      runfile = Runx.runfile_path(dir)
      return runfile if File.exist?(runfile)
    end

    raise RunxError.new('no Runfile.rb found')
  end

  restore_env = lambda do
    map = {
      'LD_LIBRARY_PATH' => 'RUNX_LD_LIBRARY_PATH',
      'DYLD_LIBRARY_PATH' => 'RUNX_DYLD_LIBRARY_PATH',
      'TERMINFO' => 'RUNX_TERMINFO',
      'SSL_CERT_DIR' => 'RUNX_SSL_CERT_DIR',
      'SSL_CERT_FILE' => 'RUNX_SSL_CERT_FILE',
      'RUBYOPT' => 'RUNX_RUBYOPT',
      'RUBYLIB' => 'RUNX_RUBYLIB',
      'GEM_HOME' => 'RUNX_GEM_HOME',
      'GEM_PATH' => 'RUNX_GEM_PATH'
    }

    map.each do |real, temp|
      orig = ENV[temp]
      if orig.nil? || orig.strip.empty?
        ENV.delete(real)
      else
        ENV[real] = orig.strip
      end
    end

    map.values.each do |temp|
      ENV.delete(temp)
    end
  end

  # Restore environment to match original.
  restore_env.call

  runfile = find_runfile.call
  manager = Runx.load(runfile)

  show_help = ARGV.empty? || (ARGV.length == 1 && ['-h', '--help', 'help', '/?', '-?'].include?(ARGV[0]))
  if show_help
    $stderr.puts "[runx] in #{File.dirname(runfile)}"
    $stderr.puts
    manager.show_help
  else
    # Clear ARGV to avoid interference with `gets`:
    # http://ruby-doc.org/core-2.1.5/Kernel.html#method-i-gets
    args = ARGV[0...ARGV.length]
    ARGV.clear

    # Pass-through task exit code.
    exit manager.run_task(args)
  end
rescue Runx::RunxError => e
  $stderr.puts "[runx] #{'error'.red.bold}: #{e}"
  exit 1
rescue Interrupt => e
  # Ignore interrupt and exit.
end