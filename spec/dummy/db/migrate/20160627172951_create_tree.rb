class CreateTree < ActiveRecord::Migration
  def change
    create_table :trees do |t|
      t.string :name
      t.references :owner, index: true
    end
  end
end
