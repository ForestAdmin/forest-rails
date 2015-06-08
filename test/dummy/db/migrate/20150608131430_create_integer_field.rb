class CreateIntegerField < ActiveRecord::Migration
  def change
    create_table :integer_fields do |t|
      t.integer :field
    end
  end
end
