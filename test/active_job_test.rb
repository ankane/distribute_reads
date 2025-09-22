require_relative "test_helper"

class ActiveJobTest < Minitest::Test
  def test_default
    TestJob.perform_now
    assert_equal "replica", $current_database
  end

  def test_by_default
    by_default do
      ReadWriteJob.perform_now
      assert_equal "replica", $current_database

      ReadWriteJob.perform_now
      assert_equal "replica", $current_database
    end
  end
end
