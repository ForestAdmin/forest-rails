class CreateDrivers < ActiveRecord::Migration[6.0]
  def change
    Driver.connection.create_table :drivers do |t|
      t.string :firstname
    end
  end
end
