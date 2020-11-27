class CreateTree < ActiveRecord::Migration[4.2]
  def change
    create_table :trees do |t|
      t.string :name
      t.references :owner, index: true
    end
  end
end
