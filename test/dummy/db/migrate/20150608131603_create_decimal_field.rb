class CreateDecimalField < ActiveRecord::Migration[4.2]
  def change
    create_table :decimal_fields do |t|
      t.decimal :field
    end
  end
end
