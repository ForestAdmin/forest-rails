class CreatePolymorphicField < ActiveRecord::Migration[4.2]
  def change
    create_table :polymorphic_fields do |t|
      t.references :has_one_field, index: true
    end
  end
end
