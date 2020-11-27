class CreateOwner < ActiveRecord::Migration[4.2]
  def change
    create_table :owners do |t|
      t.string :name
    end
  end
end
