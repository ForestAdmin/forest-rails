class CreateStringField < ActiveRecord::Migration
  def change
    create_table :string_fields do |t|
      t.string :field
    end
  end
end
