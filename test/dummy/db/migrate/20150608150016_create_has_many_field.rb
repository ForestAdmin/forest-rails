class CreateHasManyField < ActiveRecord::Migration[4.2]
  def change
    create_table :has_many_fields do |t|
      t.references :has_many_through_field, index: true
    end
  end
end
