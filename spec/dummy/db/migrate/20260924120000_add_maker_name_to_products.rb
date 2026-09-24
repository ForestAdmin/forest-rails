class AddMakerNameToProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :products, :maker_name, :string
  end
end
