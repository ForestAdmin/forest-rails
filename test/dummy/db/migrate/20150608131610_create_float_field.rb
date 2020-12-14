class CreateFloatField < ActiveRecord::Migration[4.2]
  def change
    create_table :float_fields do |t|
      t.float :field
    end
  end
end
