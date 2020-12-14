class AddTypeToUser < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :title, :integer
  end
end
