class CreateMotors < ActiveRecord::Migration[6.0]
  def change
    create_table :motors do |t|
      t.string :description
      t.string :voltage
    end
  end
end
