class CreateBooleanField < ActiveRecord::Migration[4.2]
  def change
    create_table :boolean_fields do |t|
      t.boolean :field
    end
  end
end
