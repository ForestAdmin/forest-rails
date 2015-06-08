class CreateBooleanField < ActiveRecord::Migration
  def change
    create_table :boolean_fields do |t|
      t.boolean :field
    end
  end
end
