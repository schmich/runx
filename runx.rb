require 'pathname'

class Task
  def initialize(name, block, doc, dir, auto)
    @name = name
    @block = block
    @doc = doc
    @dir = dir
    @auto = auto
  end

  def run(manager, *args)
    raise DirNotFoundError.new(@dir, self) if !File.exist?(@dir)
    Dir.chdir(@dir) do
      $stderr.puts "[runx] In #{@dir}."
      @block.call(*args)
    end
  end

  def auto?
    @auto
  end

  attr_accessor :name, :doc
end

class TaskNotFoundError < StandardError
  def initialize(name)
    @name = name
  end

  attr_reader :name
end

class DirNotFoundError < StandardError
  def initialize(dir, task)
    @dir = dir
    @task = task
  end

  attr_reader :dir, :task
end

class DuplicateTaskError < StandardError
  def initialize(name)
    @name = name
  end

  attr_reader :name
end

class MultipleAutoError < StandardError
  def initialize(auto, current)
    @auto = auto
    @current = current
  end

  attr_reader :auto, :current
end

class MultipleRunfileError < StandardError
  def initialize(path, files)
    @path = path
    @files = files.map { |file| File.basename(file) }
  end

  attr_reader :path, :files
end

class NoTasksDefinedError < StandardError
end

class DirAttributeError < StandardError
  def initialize(base)
    @base = base
  end

  attr_reader :base
end

class TaskManager
  def initialize
    @tasks = {}
  end

  def load(file)
    @tasks.merge!(load_tasks(file))
    raise NoTasksDefinedError if @tasks.empty?
  end

  def show_help
    $stderr.puts 'Tasks:'

    # Format to show which task is the auto task, if any.
    tasks = Hash[@tasks.map { |name, task|
      [name + (task.auto? ? '*' : ''), task]
    }]

    width = tasks.keys.map(&:length).max
    tasks.each do |name, task|
      space = ' ' * (width - name.length + 6)
      $stderr.puts "  #{name}#{space}#{task.doc}"
    end
  end

  def auto_task
    task = @tasks.values.find(&:auto?)
    task.name if task
  end

  def task_defined?(name)
    !@tasks[name.to_s.downcase].nil?
  end

  def run_task(name, *args)
    task = @tasks[name.to_s.downcase]
    raise TaskNotFoundError.new(name) if task.nil?
    task.run(self, *args)
  end

  private

  def load_tasks(file)
    context = TaskContext.new(File.dirname(file), self)
    proxy = TaskContextProxy.new(context)
    InstanceBinding.for(proxy).eval(File.read(file), file)
    context.tasks
  end
end

module InstanceBinding
  def self.for(object)
    @object = object
    create
  end

  def self.create
    @object.instance_eval { binding }
  end
end

class TaskContextProxy
  def initialize(real)
    @_ = real
  end

  def auto
    @_.auto
  end

  def dir(base, relative = '.')
    @_.dir(base, relative)
  end

  def doc(doc)
    @_.doc(doc)
  end

  def run(*args, &block)
    @_.run(*args, &block)
  end
end

class TaskContext
  def initialize(root_dir, manager)
    @tasks = {}
    @doc = nil
    @auto = false
    @auto_task = nil
    @task_dir = nil
    @root_dir = root_dir
    @manager = manager
  end

  def auto
    @auto = true
  end

  def dir(base, relative = '.')
    path = case base
      when :pwd
        Dir.pwd
      when :root
        @root_dir
      else
        raise DirAttributeError.new(base)
    end
    @task_dir = File.absolute_path(File.join(path, relative.to_s))
  end

  def doc(doc)
    @doc = doc
  end

  def run(*args, &block)
    if block_given?
      # Define task.
      name = args.first
      key = name.to_s.downcase

      if @tasks.include?(key)
        raise DuplicateTaskError.new(name)
      end

      task = Task.new(name.to_s, block, @doc, @task_dir || @root_dir, @auto)
      @tasks[key] = task

      if @auto
        if @auto_task
          raise MultipleAutoError.new(@auto_task, task)
        else
          @auto_task = task
        end
      end

      @task_dir = nil
      @doc = nil
      @auto = false
    else
      # Invoke task.
      name = args.first
      args = args.drop(1)
      @manager.run_task(name, *args)
    end
  end

  attr_accessor :tasks
end

def restore_env
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

def find_runfile
  Pathname.getwd.ascend do |path|
    files = ['Runfile', 'Runfile.rb'].map { |file|
      File.join(path.to_s, file)
    }.select { |file|
      File.exist?(file)
    }
    if files.length == 1
      return files.first.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
    elsif files.length == 2
      raise MultipleRunfileError.new(path, files)
    end
  end

  return nil
end

# Restore environment to match original.
restore_env

begin
  runfile = find_runfile
  if runfile.nil?
    $stderr.puts '[runx] Error: No Runfile or Runfile.rb found.'
    exit 1
  end

  manager = TaskManager.new
  manager.load(runfile)

  task_name = ARGV[0] || manager.auto_task

  is_help = ['-h', '--help', 'help'].include?(task_name)
  show_help = !task_name || (is_help && !manager.task_defined?(task_name))

  if show_help
    $stderr.puts "[runx] In #{File.dirname(runfile)}."
    $stderr.puts
    manager.show_help
  else
    # Clear ARGV to avoid interference with `gets`:
    # http://ruby-doc.org/core-2.1.5/Kernel.html#method-i-gets
    args = ARGV[1...ARGV.length]
    ARGV.clear

    manager.run_task(task_name, *args)
  end
rescue MultipleRunfileError => e
  $stderr.puts "[runx] Error: Multiple Runfiles found in #{e.path}: #{e.files.join(', ')}."
  exit 1
rescue NoTasksDefinedError => e
  $stderr.puts '[runx] Error: No tasks defined. See https://github.com/schmich/runx#usage.'
  exit 1
rescue TaskNotFoundError => e
  $stderr.puts "[runx] Error: Task '#{e.name}' not found."
  exit 1
rescue DuplicateTaskError => e
  $stderr.puts "[runx] Error: Task '#{e.name}' is already defined."
  exit 1
rescue MultipleAutoError => e
  $stderr.puts "[runx] Error: Task '#{e.current.name}' cannot be auto, '#{e.auto.name}' is already auto."
  exit 1
rescue DirNotFoundError => e
  $stderr.puts "[runx] Error: Task #{e.task.name}: Directory not found: #{e.dir}."
  exit 1
rescue DirAttributeError => e
  $stderr.puts "[runx] Error: Invalid attribute 'dir :#{e.base}'. Expected :root or :pwd."
  exit 1
rescue Interrupt => e
  # Ignore interrupt and exit.
end
