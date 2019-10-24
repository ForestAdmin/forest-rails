require 'test_helper'

class ForestLianaTest < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, ForestLiana
  end

  test 'config_dirs with no value set' do
    assert_equal(
      Rails.root.join('lib/forest_liana/**/*.rb'),
      ForestLiana.config_dir
    )
  end

  test 'config_dirs with a value set' do
    ForestLiana.config_dir = 'lib/custom/**/*.rb'

    assert_equal(
      Rails.root.join('lib/custom/**/*.rb'),
      ForestLiana.config_dir
    )

    ForestLiana.config_dir = 'lib/forest_liana/**/*.rb'
  end
end
