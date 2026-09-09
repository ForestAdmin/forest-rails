class CreateMemberships < ActiveRecord::Migration[6.0]
  def change
    create_table :memberships do |t|
      t.references :island, null: false
      t.references :user, null: false

      t.timestamps
    end
  end
end
