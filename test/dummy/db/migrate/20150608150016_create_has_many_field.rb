class CreateHasManyField < ActiveRecord::Migration
  def change
    create_table :has_many_fields do |t|
      t.references :has_many_through_field, index: true
    end
  end
end
