class CreateOwner < ActiveRecord::Migration
  def change
    create_table :owners do |t|
      t.string :name
    end
  end
end
