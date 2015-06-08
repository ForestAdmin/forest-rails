class CreateFloatField < ActiveRecord::Migration
  def change
    create_table :float_fields do |t|
      t.float :field
    end
  end
end
