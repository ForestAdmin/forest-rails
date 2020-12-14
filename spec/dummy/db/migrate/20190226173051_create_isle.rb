class CreateIsle < ActiveRecord::Migration[4.2]
  def change
    create_table :isle do |t|
      t.string :name
      t.binary :map

      t.timestamps
    end
  end
end
