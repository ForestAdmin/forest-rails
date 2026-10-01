class CreateHarborsBoatsCaptainsLicenses < ActiveRecord::Migration[6.0]
  def change
    create_table :harbors do |t|
      t.string :name
    end

    create_table :captains do |t|
      t.string :name
      t.string :license_number
    end

    create_table :licenses do |t|
      t.string :number
      t.date :expires_on
    end

    create_table :boats do |t|
      t.string :name
      t.references :harbor
      t.references :captain
    end
  end
end
