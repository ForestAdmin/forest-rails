class CreateDateField < ActiveRecord::Migration[4.2]
  def change
    create_table :date_fields do |t|
      t.date :field
    end
  end
end
