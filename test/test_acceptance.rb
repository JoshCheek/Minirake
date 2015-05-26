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
        task default: :e
        task(:a)              { puts :a }
        task(b: :a)           { puts :b }
        task(c: :b)           { puts :c }
        task(d: :c)           { puts :d }
        task(e: [:a, :b, :d]) { puts :e }
        task(:e) { puts "ENV['ABC']: \#{ENV['ABC'].inspect}" }
        task(:e) { puts File.basename(__FILE__), __LINE__ }
      RAKEFILE

      result = invoke 'minirake', 'ABC=DEF', from: dir
      assert_equal "", result.stderr
      assert_equal "a\nb\nc\nd\ne\nENV['ABC']: \"DEF\"\nMinirakefile\n8\n",
                   result.stdout
      assert_equal 0, result.exitstatus
    end
  end
end
