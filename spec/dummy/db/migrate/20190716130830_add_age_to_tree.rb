class AddAgeToTree < ActiveRecord::Migration
  def up
    add_column :trees, :age, :integer
  end
end
