class CreateTreesUsers < ActiveRecord::Migration[6.0]
  def change
    create_join_table :trees, :users do |t|
      t.index [:tree_id, :user_id]
    end
  end
end
