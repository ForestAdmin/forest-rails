class CreatePolymorphicField < ActiveRecord::Migration
  def change
    create_table :polymorphic_fields do |t|
      t.references :has_one_field, index: true
    end
  end
end
