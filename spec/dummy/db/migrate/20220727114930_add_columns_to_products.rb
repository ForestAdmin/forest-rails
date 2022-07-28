class AddColumnsToProducts < ActiveRecord::Migration[6.0]
  def change
    change_table :products do |table|
      table.string :name
      table.belongs_to(:manufacturer)
      table.belongs_to(:driver)
    end
  end
end
