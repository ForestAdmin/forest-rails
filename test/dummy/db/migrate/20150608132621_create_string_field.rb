class CreateStringField < ActiveRecord::Migration[4.2]
  def change
    create_table :string_fields do |t|
      t.string :field
    end
  end
end
