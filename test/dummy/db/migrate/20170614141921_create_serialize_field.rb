class CreateSerializeField < ActiveRecord::Migration
  def change
    create_table :serialize_fields do |t|
      t.string :field
    end
  end
end
