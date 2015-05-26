class Minirake
  Error = Class.new ::StandardError

  class InvalidTaskDeclaration < Error
    attr_accessor :declaration
    def initialize(declaration)
      self.declaration = declaration
      super declaration.inspect
    end
  end

  InvalidTaskName = Class.new InvalidTaskDeclaration

  class CircularDependency < Error
    attr_accessor :path
    def initialize(path)
      self.path = path
      super path.inspect
    end
  end

  class NoSuchTask < Error
    attr_accessor :task_name
    def initialize(task_name)
      self.task_name = task_name
      super task_name.to_s
    end
  end

  def self.extract_env(name)
    name = name.to_s
    return nil unless name['=']
    key, value = name.split('=', 2)
    value = nil if value == ""
    [key, value]
  end

  attr_reader :tasks, :env

  def initialize(env: {})
    @env   = env
    @tasks = {}
  end

  def call(args)
    tasks = set_env_vars(args, env)
    tasks << :default if tasks.empty?
    tasks.each { |name| satisfy name }
  end

  def set_env_vars(args, env)
    args.reject { |arg|
      key, value = self.class.extract_env arg
      if key
        env[key] = value
        true
      end
    }
  end

  def satisfy(name, path=[])
    path = path + [name]
    raise CircularDependency, path if 1 < path.select { |n| n == name }.count

    task = task_for name
    raise NoSuchTask, name unless task

    task.dependency_names.each { |dep| satisfy dep, path }
    task.invoke
  end

  def task(declaration, &body)
    name = deps = nil
    case declaration
    when Hash           then name, deps = declaration.first
    when Symbol, String then name, deps = declaration.intern, []
    else raise InvalidTaskDeclaration, declaration
    end
    ensure_task(name).add_deps(deps).add_body(body)
    self
  end

  def task_for(name)
    raise InvalidTaskName, name unless name.respond_to? :intern
    tasks[name.intern]
  end

  private

  def ensure_task(name)
    name        ||= name.intern
    tasks[name] ||= Task.new(name: name)
  end


  class Task
    attr_accessor :name, :bodies, :dependency_names

    def initialize(name:)
      self.name             = name
      self.bodies           = []
      self.dependency_names = []
    end

    def add_deps(deps)
      Array(deps).map(&:intern).each do |dep|
        dependency_names << dep unless dependency_names.include? dep
      end
      self
    end

    def add_body(body)
      bodies << body if body
      self
    end

    def invoke
      bodies.each &:call unless satisfied?
      satisfied!
      self
    end

    def satisfied!
      @satisfied = true
    end

    def satisfied?
      !!@satisfied
    end
  end
end
