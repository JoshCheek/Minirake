require 'tmpdir'
require 'open3'

class TestAcceptance < Minitest::Test
  ProcessResult = Struct.new :stdout, :stderr, :status do
    def exitstatus
      status.exitstatus
    end
  end

  def invoke(executable, *args, from:)
    bin_path      = File.expand_path '../bin', __dir__
    original_path = ENV['PATH']
    Dir.chdir from do
      ENV['PATH'] = "#{bin_path}:#{original_path}"
      ProcessResult.new(*Open3.capture3(executable, *args))
    end
  ensure
    ENV['PATH'] = original_path
  end

  def test_acceptance
    Dir.mktmpdir do |dir|
      File.write "#{dir}/Minirakefile", <<-RAKEFILE
        task :correct_file_and_line do
          puts File.basename(__FILE__), __LINE__
        end

        task(:a)                     { puts :a }
        task(b: :a)                  { puts :b }
        task(c: :b)                  { puts :c }
        task(d: :c)                  { puts :d }
        task(ordering: [:a, :b, :d]) { puts :ordering }

        task :env_vars_get_set do
          puts "ENV['ABC']: \#{ENV['ABC'].inspect}"
        end

        def the_method; "Method got defined"; end
        task :can_define_methods do
          puts the_method
          puts "My class: \#{self.class}"
          puts "Method is on Minirake: \#{Minirake.instance_methods.include?(:the_method)}"
          puts "Method is on singleton class: \#{singleton_methods.include? :the_method}"
        end

        task default: :correct_file_and_line
        task default: :ordering
        task default: :can_define_methods
        task default: :env_vars_get_set
      RAKEFILE

      result = invoke 'minirake', 'ABC=DEF', from: dir

      assert_equal "", result.stderr

      assert_equal "Minirakefile\n2\n"                     +
                   "a\nb\nc\nd\nordering\n"                +
                   "Method got defined\n"                  +
                   "My class: Minirake\n"                  +
                   "Method is on Minirake: false\n"        +
                   "Method is on singleton class: true\n"  +
                   "ENV['ABC']: \"DEF\"\n",
                   result.stdout

      assert_equal 0, result.exitstatus
    end
  end
end
