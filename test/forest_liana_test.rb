require 'test_helper'

class ForestLianaTest < ActiveSupport::TestCase
  include RSpec::Matchers

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

  # Default logger is overrided by application bootstrap
  # Test catches the output to $stdout with the help of rails-expectations
  test 'override the log formatter' do
    expect { FOREST_LOGGER.error "[error] override logger" }.to output({:message => "[error] override logger"}.to_json).to_stdout_from_any_process
    expect { FOREST_LOGGER.info "[info] override logger" }.to output({:message => "[info] override logger"}.to_json).to_stdout_from_any_process
  end
end
