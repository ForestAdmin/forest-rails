class CreateIntegerField < ActiveRecord::Migration[4.2]
  def change
    create_table :integer_fields do |t|
      t.integer :field
    end
  end
end
