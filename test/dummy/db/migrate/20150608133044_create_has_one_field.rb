class CreateHasOneField < ActiveRecord::Migration
  def change
    create_table :has_one_fields do |t|
      t.boolean :checked
      t.column :status, :integer, default: 0
    end
  end
end
