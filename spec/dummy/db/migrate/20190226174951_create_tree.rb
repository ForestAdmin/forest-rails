class CreateTree < ActiveRecord::Migration[4.2]
  def change
    create_table :trees do |t|
      t.string :name
      t.references :owner, index: true
      t.references :cutter, index: true
      t.references :island, index: true

      t.timestamps
    end
  end
end
