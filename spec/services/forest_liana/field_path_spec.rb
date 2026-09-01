module ForestLiana
  describe FieldPath do
    describe 'leaf_collection_names' do
      it 'answers the collection itself for one of its own columns' do
        expect(FieldPath.leaf_collection_names(Tree, 'name')).to eq(['Tree'])
      end

      it 'answers only the collection a path ends on, not the one it crosses' do
        expect(FieldPath.leaf_collection_names(Tree, 'island:name')).to eq(['Island'])
      end

      it 'answers the leaf of a path crossing two relations' do
        expect(FieldPath.leaf_collection_names(Tree, 'island:location:id')).to eq(['Location'])
      end

      it 'answers the target of a polymorphic relation reached through another relation' do
        expect(FieldPath.leaf_collection_names(User, 'addresses:addressable:id')).to eq(['User'])
      end

      it 'stops resolving at the polymorphic relation, whatever segment follows it' do
        expect(FieldPath.leaf_collection_names(User, 'addresses:addressable:whatever')).to eq(['User'])
      end

      it 'answers the target of a bare relation name with no trailing column' do
        expect(FieldPath.leaf_collection_names(Tree, 'island')).to eq(['Island'])
      end

      it 'raises rather than falling back to the root when the prefix names nothing' do
        expect { FieldPath.leaf_collection_names(Tree, 'unknown:id') }
          .to raise_error(Errors::HTTP422Error, "Relation not found: 'Tree.unknown'")
      end

      it 'raises rather than falling back to the root when the prefix is a column' do
        expect { FieldPath.leaf_collection_names(Tree, 'name:id') }
          .to raise_error(Errors::HTTP422Error, "Relation not found: 'Tree.name'")
      end

      it 'raises rather than falling back to the root on a trailing colon naming no relation' do
        expect { FieldPath.leaf_collection_names(Tree, 'unknown:') }
          .to raise_error(Errors::HTTP422Error, "Relation not found: 'Tree.unknown'")
      end

      it 'raises rather than falling back to the root on a trailing colon naming a column' do
        expect { FieldPath.leaf_collection_names(Tree, 'name:') }
          .to raise_error(Errors::HTTP422Error, "Relation not found: 'Tree.name'")
      end

      it 'raises when given a record instead of a model class' do
        expect { FieldPath.leaf_collection_names(Island.new, 'name') }.to raise_error(ArgumentError)
      end

      it 'raises when given a class that is not an ActiveRecord model' do
        expect { FieldPath.leaf_collection_names(String, 'anything') }.to raise_error(ArgumentError)
      end

      context 'on a polymorphic relation with several targets' do
        before do
          Island.class_eval { has_many :addresses, as: :addressable }
        end

        after do
          %w[addresses].each do |name|
            Island._reflections.delete(name)
            Island.reflections.delete(name)
          end
          %w[addresses addresses= address_ids address_ids=].each do |method|
            Island.undef_method(method) rescue nil
          end
        end

        it 'answers every target of the polymorphic relation' do
          expect(FieldPath.leaf_collection_names(Address, 'addressable:id'))
            .to match_array(%w[User Island])
        end

        it 'answers every target of a bare polymorphic relation with no trailing column' do
          expect(FieldPath.leaf_collection_names(Address, 'addressable')).to match_array(%w[User Island])
        end
      end

      context 'on a polymorphic relation with no declared target' do
        before do
          Tree.class_eval { belongs_to :subject, polymorphic: true, optional: true }
        end

        after do
          %w[subject].each do |name|
            Tree._reflections.delete(name)
            Tree.reflections.delete(name)
          end
          %w[subject subject= subject_id subject_type].each do |method|
            Tree.undef_method(method) rescue nil
          end
        end

        it 'answers an empty list, not the root collection' do
          expect(FieldPath.leaf_collection_names(Tree, 'subject:id')).to eq([])
        end
      end
    end

    describe 'readable_leaves?' do
      it 'reads an empty list as denied' do
        expect(FieldPath.readable_leaves?([], %w[User])).to be false
      end

      it 'allows a path only when every leaf collection is readable' do
        expect(FieldPath.readable_leaves?(%w[User Island], %w[User Island])).to be true
      end

      it 'denies a path when one leaf collection is not readable' do
        expect(FieldPath.readable_leaves?(%w[User Island], %w[User])).to be false
      end
    end

    describe 'leaf_label' do
      it 'names a single collection' do
        expect(FieldPath.leaf_label(['User'])).to eq("the 'User' collection")
      end

      it 'joins several collections with or' do
        expect(FieldPath.leaf_label(%w[User Island])).to eq("the 'User' or 'Island' collection")
      end

      it 'names an unresolved polymorphic relation for an empty list' do
        expect(FieldPath.leaf_label([])).to eq('an unresolved polymorphic relation')
      end
    end
  end
end
