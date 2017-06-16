class CreateSerializeAndBelongsToField < ActiveRecord::Migration
  def change
    create_table :serialize_and_belongs_to_fields do |t|
      t.string :field
      t.references :has_one_field, index: true
    end
  end
end
