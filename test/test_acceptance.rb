require 'tmpdir'

class TestAcceptance < Minitest::Test
  def test_acceptance
    order = []

    minirake = Minirake.new
    minirake.task default: :e
    minirake.task(:a)              { order << :a }
    minirake.task(b: :a)           { order << :b }
    minirake.task(c: :b)           { order << :c }
    minirake.task(d: :c)           { order << :d }
    minirake.task(e: [:a, :b, :d]) { order << :e }
    minirake.call []

    assert_equal [:a, :b, :c, :d, :e], order
  end
end
