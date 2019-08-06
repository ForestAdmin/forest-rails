class AddTypeToUser < ActiveRecord::Migration
  def up
    add_column :users, :title, :integer
  end
end
