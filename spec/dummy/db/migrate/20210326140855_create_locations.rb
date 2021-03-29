class CreateLocations < ActiveRecord::Migration[6.0]
  def change
    create_table :locations do |t|
      t.string :coordinates
      t.references :island, index: true

      t.timestamps
    end
  end
end
