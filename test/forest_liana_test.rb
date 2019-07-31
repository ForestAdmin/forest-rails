require 'test_helper'

class ForestLianaTest < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, ForestLiana
  end

  test "error_handler is a proc" do
    assert_kind_of Proc, ForestLiana.error_handler
  end
end
