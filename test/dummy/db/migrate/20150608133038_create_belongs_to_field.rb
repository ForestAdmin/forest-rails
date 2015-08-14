class CreateBelongsToField < ActiveRecord::Migration
  def change
    create_table :belongs_to_fields do |t|
      t.references :has_one_field, index: true
      t.references :has_many_class_name_field, index: true
      t.references :has_many_field, index: true
    end
  end
end
