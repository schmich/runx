require 'pathname'

class Task
  def initialize(name, doc, block, dir)
    @name = name
    @doc = doc
    @block = block
    @dir = dir
  end

  def run(manager, *args)
    Dir.chdir(@dir) do
      @block.call(*args)
    end
  end

  attr_accessor :name, :doc
end

class TaskNotFoundError < StandardError
  def initialize(name)
    @name = name
  end

  attr_reader :name
end

class DuplicateTaskError < StandardError
  def initialize(name)
    @name = name
  end

  attr_reader :name
end

class TaskManager
  def initialize
    @tasks = {}
  end

  def load(file)
    dir = File.dirname(file)
    context = TaskContext.new(dir, self)
    context.instance_eval(File.read(file), file)
    @tasks.merge!(context.tasks)
  end

  def show_help
    $stderr.puts 'Tasks:'
    width = @tasks.map { |name, task| name.length }.max
    @tasks.each do |name, task|
      space = ' ' * (width - name.length + 6)
      $stderr.puts "  #{task.name}#{space}#{task.doc}"
    end
  end

  def run_task(name, *args)
    task = @tasks[name.to_s.downcase]
    if task.nil?
      raise TaskNotFoundError.new(name)
    end

    task.run(self, *args)
  end
end

class TaskContext
  def initialize(dir, manager)
    @tasks = {}
    @doc = nil
    @dir = dir
    @manager = manager
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

      @tasks[key] = Task.new(name.to_s, @doc, block, @dir)
      @doc = nil
    else
      # Invoke task.
      name = args.first
      args = args.drop(1)
      @manager.run_task(name, *args)
    end
  end

  attr_accessor :tasks
end

def find_runfile
  Pathname.getwd.ascend do |path|
    runfile = File.join(path.to_s, 'Runfile')
    if File.exist?(runfile)
      return runfile.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
    end
  end

  return nil
end

runfile = find_runfile
if runfile.nil?
  $stderr.puts '[runx] No Runfile found.'
  exit 1
end

begin
  manager = TaskManager.new
  manager.load(runfile)

  dir = File.dirname(runfile)
  $stderr.puts "[runx] In #{dir}."

  task_name = ARGV[0]
  if !task_name
    $stderr.puts
    manager.show_help
  else
    # Clear ARGV to avoid interference with `gets`:
    # http://ruby-doc.org/core-2.1.5/Kernel.html#method-i-gets
    args = ARGV[1...ARGV.length]
    ARGV.clear

    manager.run_task(task_name, *args)
  end
rescue TaskNotFoundError => e
  $stderr.puts "[runx] Task '#{e.name}' not found."
  exit 1
rescue DuplicateTaskError => e
  $stderr.puts "[runx] Task '#{e.name}' is already defined."
  exit 1
rescue Interrupt => e
  # Ignore interrupt and exit.
end
