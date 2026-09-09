class CreateFlags < ActiveRecord::Migration[6.0]
  def change
    create_table :flags do |t|
      t.references :island
      t.string :color

      t.timestamps
    end
  end
end
