class CreateArticlesAndTaggings < ActiveRecord::Migration[6.0]
  def change
    create_table :articles do |t|
      t.string :title

      t.timestamps
    end

    # Consolidates acts_as_taggable_on's own migration templates (1, 2, 4, 6, 7 — not 5, a MySQL
    # collation fix) for the one dummy model that needs it (Article), rather than depending on the
    # gem's install generator here.
    create_table :tags do |t|
      t.string :name
      t.integer :taggings_count, default: 0

      t.timestamps
    end
    add_index :tags, :name, unique: true

    create_table :taggings do |t|
      t.references :tag, foreign_key: { to_table: :tags }
      t.references :taggable, polymorphic: true
      t.references :tagger, polymorphic: true
      t.string :context, limit: 128
      t.string :tenant, limit: 128

      t.datetime :created_at
    end
    add_index :taggings, %i[tag_id taggable_id taggable_type context tagger_id tagger_type],
      unique: true, name: 'taggings_idx'
    add_index :taggings, %i[taggable_id taggable_type context], name: 'taggings_taggable_context_idx'
    add_index :taggings, :tenant
  end
end
