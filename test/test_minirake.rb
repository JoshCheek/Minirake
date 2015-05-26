require 'minirake'
require 'minitest/spec'

describe 'minirake' do
  describe 'environment variables' do
    it 'considers names with equal signs to be environment variables' do
      assert_equal ['A',   'B'],   Minirake.extract_env('A=B')
      assert_equal ['ABC', 'DEF'], Minirake.extract_env('ABC=DEF')
      assert_equal ['abc', 'def'], Minirake.extract_env('abc=def')
      assert_equal ['abc', 'def'], Minirake.extract_env(:'abc=def')
      assert_equal ['abc', nil],   Minirake.extract_env('abc=')
      assert_equal ['abc', 'd=f'], Minirake.extract_env('abc=d=f')
      assert_equal nil,            Minirake.extract_env('abc')
    end

    it 'sets environment variables before calling any tasks' do
      env = {}
      Minirake.new(env: env)
              .task(:a) {
                assert_equal 'B', env['A']
                assert_equal 'D', env['C']
              }
              .call(%w[A=B a C=D])
      # just b/c if it didn't call them in a case like this, we'd pass even if it didn't set them
      assert_equal({'A' => 'B', 'C' => 'D'}, env)
    end
  end

  describe 'records a task' do
    def minirake
      @minirake ||= Minirake.new
    end

    specify 'with a string or symbol name' do
      minirake.task(:a)
      minirake.task('b')
      # success is if it doesn't blow up
      minirake.task_for(:a)
      minirake.task_for(:b)
    end

    it 'with or without a body' do
      minirake.task(:a) { 1 }
      minirake.task(:b)
      assert_equal [1], minirake.task_for(:a).bodies.map(&:call)
      assert_equal [],  minirake.task_for(:b).bodies.map(&:call)
    end

    it 'with or without without dependencies' do
      minirake.task(:a)
      assert_equal [], minirake.task_for(:a).dependency_names

      minirake.task(b: [:a])
      assert_equal [:a], minirake.task_for(:b).dependency_names
    end

    it 'with a string, symbol, or array dependencies' do
      minirake.task(a: 'x')
      minirake.task(b: :x)
      minirake.task(c: [:x, 'y'])

      assert_equal [:x], minirake.task_for(:a).dependency_names
      assert_equal [:x], minirake.task_for(:b).dependency_names
      assert_equal [:x, :y], minirake.task_for(:c).dependency_names
    end

    it 'consolidates equivalent dependency names' do
      minirake.task(a: 'x')
      minirake.task(a: :x)
      minirake.task(a: 'x')
      minirake.task(a: :x)
      assert_equal [:x], minirake.task_for(:a).dependency_names
    end

    it 'raises on other args passed to declarations' do
      assert_raises(Minirake::InvalidTaskDeclaration) { minirake.task 123 }
    end
  end

  describe 'dependencies' do
    it 'invokes tasks with string / symbol names, and raises otherwise' do
      seen = []
      assert_raises Minirake::InvalidTaskName do
        Minirake.new.task(:a)  { seen << :a }
                    .task(:b)  { seen << :b }
                    .task('c') { seen << :c }
                    .task('d') { seen << :d }
                    .task(:e)  { seen << :e }
                    .call([:a, 'b', :c, 'd', Object.new])
      end
      assert_equal [:a, :b, :c, :d], seen
    end

    it 'invokes the task\'s dependencies before the task' do
      order = []

      minirake = Minirake.new
      minirake.task(:a)    { order << :a }
      minirake.task(b: :a) { order << :b }
      minirake.call [:b]

      assert_equal [:a, :b], order
    end

    it 'invokes the task\'s dependencies from left to right' do
      order1 = []
      order2 = []
      Minirake.new.task(:a) { order1 << :a }.task(:b) { order1 << :b }.call([:a, :b])
      Minirake.new.task(:a) { order2 << :a }.task(:b) { order2 << :b }.call([:b, :a])
      assert_equal [:a, :b], order1
      assert_equal [:b, :a], order2
    end

    it 'does not invoke the dependency if the dependency has already been satisfied' do
      order = []
      minirake = Minirake.new.task(:a) { order << :a }
      minirake.call [:a]
      minirake.call [:a]
      assert_equal [:a], order
    end

    it 'invokes the default task if no task is specified' do
      order = []
      Minirake.new.task(default: :b)
                  .task(:a) { order << :a }
                  .task(:b) { order << :b }
                  .task(:c) { order << :c }
                  .call([])
      assert_equal [:b], order
    end

    it 'invokes the default task when environment variables are provided, but no task is' do
      env, seen = {}, false
      Minirake.new(env: env)
        .task(:default) {
          seen = true
          assert_equal 'B', env['A']
        }.call(['A=B'])
      assert_equal true, seen
    end

    it 'doesn\'t recursively deadlock' do
      assert_raises Minirake::CircularDependency do
        Minirake.new.task(a: :b).task(b: :a).call([:a])
      end
    end

    it 'raises when the task DNE' do
      assert_raises Minirake::NoSuchTask do
        Minirake.new.task(:a).call([:b])
      end
    end

    it 'consolidates task declarations' do
      minirake = Minirake.new
                         .task(:a) { 1 }
                         .task(:a) { 2 }
                         .task(a: :b)
                         .task(a: [:c, :d])
      a = minirake.task_for(:a)
      assert_equal [:b, :c, :d], a.dependency_names
      assert_equal [1, 2], a.bodies.map(&:call)
    end
  end
end
