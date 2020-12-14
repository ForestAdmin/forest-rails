class CreateBelongsToClassNameField < ActiveRecord::Migration[4.2]
  def change
    create_table :belongs_to_class_name_fields do |t|
      t.references :foo, index: true
    end
  end
end
