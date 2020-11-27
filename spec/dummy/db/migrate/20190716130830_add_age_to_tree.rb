class AddAgeToTree < ActiveRecord::Migration[4.2]
  def up
    add_column :trees, :age, :integer
  end
end
