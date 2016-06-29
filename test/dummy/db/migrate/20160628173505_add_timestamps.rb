class AddTimestamps < ActiveRecord::Migration
  def change
    add_column :owners, :created_at, :datetime
    add_column :owners, :updated_at, :datetime
    add_column :trees, :created_at, :datetime
    add_column :trees, :updated_at, :datetime
  end
end
