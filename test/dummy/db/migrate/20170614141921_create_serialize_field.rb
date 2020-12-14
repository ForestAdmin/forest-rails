class CreateSerializeField < ActiveRecord::Migration[4.2]
  def change
    create_table :serialize_fields do |t|
      t.string :field
    end
  end
end
