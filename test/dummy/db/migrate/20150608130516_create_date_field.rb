class CreateDateField < ActiveRecord::Migration
  def change
    create_table :date_fields do |t|
      t.date :field
    end
  end
end
