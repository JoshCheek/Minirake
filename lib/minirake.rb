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
    tasknames = set_env_vars(args, env)
    tasknames << :default if tasknames.empty?
    tasknames.each { |name| satisfy name }
  end

  def satisfy(name, path=[])
    path += [name]
    raise CircularDependency, path if 1 < path.count { |n| n == name }

    task_for(name)
      .each_dep { |depname| satisfy depname, path }
      .satisfy!
  end

  def task(declaration, &body)
    case declaration
    when Hash           then name, deps = declaration.first
    when Symbol, String then name, deps = declaration, []
    else raise InvalidTaskDeclaration, declaration
    end
    ensure_task(name).add_deps(deps).add_body(body)
    self
  end

  def task_for(name)
    tasks.fetch(to_taskname name) { raise NoSuchTask, name }
  end

  private

  def ensure_task(name)
    name = to_taskname name
    tasks[name] ||= Task.new name: name
  end

  def to_taskname(name)
    return name.intern if name.respond_to? :intern
    raise InvalidTaskName, name
  end

  def set_env_vars(args, env)
    args.reject do |arg|
      key, value = self.class.extract_env arg
      if key
        env[key] = value
        true
      end
    end
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

    def each_dep(&block)
      dependency_names.each &block
      self
    end

    def add_body(body)
      bodies << body if body
      self
    end

    def satisfy!
      bodies.each &:call unless satisfied?
      satisfied!
    end

    def satisfied!
      @satisfied = true
      self
    end

    def satisfied?
      !!@satisfied
    end
  end
end
