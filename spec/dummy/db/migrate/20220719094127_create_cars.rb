class CreateCars < ActiveRecord::Migration[6.0]
  def change
    Car.connection.create_table :cars do |t|
      t.string :model
      t.references :driver, index: true
    end
  end
end
