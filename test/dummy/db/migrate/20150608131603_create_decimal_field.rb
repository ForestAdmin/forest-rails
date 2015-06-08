class CreateDecimalField < ActiveRecord::Migration
  def change
    create_table :decimal_fields do |t|
      t.decimal :field
    end
  end
end
