module ForestLiana
  describe FiltersParser do
    let(:timezone) { 'Europe/Paris' }
    let(:resource) { Tree }
    let(:filters) { {} }
    let(:filter_parser) { described_class.new(filters.to_json, resource, timezone) }
    let(:simple_condition_1) { { 'field' => 'name', 'operator' => 'contains', 'value' => 'Tree' } }
    let(:simple_condition_2) { { 'field' => 'name', 'operator' => 'ends_with', 'value' => '3' } }
    let(:simple_condition_3) { { 'field' => 'age', 'operator' => 'greater_than', 'value' => 2 } }
    let(:belongs_to_condition) { { 'field' => 'trees:age', 'operator' => 'less_than', 'value' => 3 } }
    let(:date_condition_1) { { 'field' => 'created_at', 'operator' => 'before', 'value' => Time.now - 2.hours } }
    let(:date_condition_2) { { 'field' => 'created_at', 'operator' => 'today' } }
    let(:date_condition_3) { { 'field' => 'created_at', 'operator' => 'previous_x_days', 'value' => 3 } }

    before {
      island = Island.create!(name: "L'île de la muerta")
      king = User.create!(title: :king)
      villager = User.create!(title: :villager)
      Tree.create!(name: 'Tree n1', age: 1, island: island, owner: king)
      Tree.create!(name: 'Tree n2', age: 3, island: island, created_at: Time.now - 1.day, owner: king)
      Tree.create!(name: 'Tree n3', age: 4, island: island, owner: king, cutter: villager)
    }

    after {
      Tree.destroy_all
      User.destroy_all
      Island.destroy_all
    }

    describe 'apply_filters' do
      context 'on valid filters' do
        let(:filters) { { aggregator: 'and', conditions: [simple_condition_1, simple_condition_2] } }
        it { expect(filter_parser.apply_filters.count).to eq 1 }
      end
    end

    describe 'parse_aggregator' do
      let(:query) { filter_parser.parse_aggregator(filters) }

      context 'when no aggregator' do
        let(:filters) { simple_condition_1 }
        it { expect(resource.where(query).count).to eq 3 }
      end

      context "'name contains \"Tree\"' 'and' 'name ends_with \"3\"'" do
        let(:filters) { { 'aggregator' => 'and', 'conditions' => [simple_condition_1, simple_condition_2] } }
        it { expect(resource.where(query).count).to eq 1 }
      end

      context "'name contains \"Tree\"' 'and' 'age greater_than 2'" do
        let(:filters) { { 'aggregator' => 'and', 'conditions' => [simple_condition_1, simple_condition_3] } }
        it { expect(resource.where(query).count).to eq 2 }
      end

      context "'name ends_with \"3\"' 'and' 'age greater_than 2'" do
        let(:filters) { { 'aggregator' => 'and', 'conditions' => [simple_condition_2, simple_condition_3] } }
        it { expect(resource.where(query).count).to eq 1 }
      end

      context "'name contains \"Tree\"' 'or' 'name ends_with \"3\"'" do
        let(:filters) { { 'aggregator' => 'or', 'conditions' => [simple_condition_1, simple_condition_2] } }
        it { expect(resource.where(query).count).to eq 3 }
      end

      context "'name contains \"Tree\"' 'or' 'age greater_than 2'" do
        let(:filters) { { 'aggregator' => 'or', 'conditions' => [simple_condition_1, simple_condition_3] } }
        it { expect(resource.where(query).count).to eq 3 }
      end

      context "'name ends_with \"3\"' 'or' 'age greater_than 2'" do
        let(:filters) { { 'aggregator' => 'or', 'conditions' => [simple_condition_2, simple_condition_3] } }
        it { expect(resource.where(query).count).to eq 2 }
      end
    end

    describe 'parse_condition' do
      let(:condition) { simple_condition_2 }
      let(:result) { filter_parser.parse_condition(condition) }

      context 'on valid condition' do
        it { expect(result).to eq "\"trees\".\"name\" LIKE '%3'" }
      end

      context 'on belongs_to condition' do
        let(:resource) { Island }
        context 'valid association' do
          let(:condition) { belongs_to_condition }
          it { expect(resource.joins(:trees).where(result).count).to eq 1 }
        end

        context 'wrong association' do
          let(:condition) { { 'field' => 'rosters:id', 'operator' => 'less_than', 'value' => 3 } }
          it {
            expect {
              filter_parser.parse_condition(condition)
            }.to raise_error(ForestLiana::Errors::HTTP422Error, "Association 'rosters' not found")
          }
        end
      end

      context 'on time based condition' do
        let(:condition) { date_condition_1 }
        it { expect(resource.where(result).count).to eq 1 }
      end

      context 'on enum condition field type' do
        let(:resource) { User }
        let(:condition) { { 'field' => 'title', 'operator' => 'equal', 'value' => 'king' } }
        it { expect(resource.where(result).count).to eq 1 }
      end
    end

    describe 'parse_aggregator_operator' do
      context 'on valid aggregator' do
        it { expect(filter_parser.parse_aggregator_operator('and')).to eq 'AND' }
        it { expect(filter_parser.parse_aggregator_operator('or')).to eq 'OR' }
      end

      context 'on unknown aggregator' do
        it {
          expect {
            filter_parser.parse_aggregator_operator('sfr')
          }.to raise_error(ForestLiana::Errors::HTTP422Error, "Unknown provided operator 'sfr'")
        }
      end
    end

    describe 'parse_operator' do
      context 'on valid operators' do
        it { expect(filter_parser.parse_operator 'not').to eq 'NOT' }
        it { expect(filter_parser.parse_operator 'greater_than').to eq '>' }
        it { expect(filter_parser.parse_operator 'after').to eq '>' }
        it { expect(filter_parser.parse_operator 'less_than').to eq '<' }
        it { expect(filter_parser.parse_operator 'before').to eq '<' }
        it { expect(filter_parser.parse_operator 'contains').to eq 'LIKE' }
        it { expect(filter_parser.parse_operator 'starts_with').to eq 'LIKE' }
        it { expect(filter_parser.parse_operator 'ends_with').to eq 'LIKE' }
        it { expect(filter_parser.parse_operator 'not_contains').to eq 'NOT_LIKE' }
        it { expect(filter_parser.parse_operator 'not_equal').to eq '!=' }
        it { expect(filter_parser.parse_operator 'present').to eq 'IS NOT NULL' }
        it { expect(filter_parser.parse_operator 'equal').to eq '=' }
        it { expect(filter_parser.parse_operator 'blank').to eq 'IS NULL' }
      end

      context 'on unknown operator' do
        it {
          expect {
            filter_parser.parse_operator('orange')
          }.to raise_error(ForestLiana::Errors::HTTP422Error, "Unknown provided operator 'orange'")
        }
      end
    end

    describe 'parse_value' do
      context 'on valid operator' do
        it { expect(filter_parser.parse_value('not', true)).to eq true }
        it { expect(filter_parser.parse_value('greater_than', 34)).to eq '34' }
        it { expect(filter_parser.parse_value('after', Time.now)).to eq Time.now.to_s }
        it { expect(filter_parser.parse_value('less_than', 45)).to eq '45' }
        it { expect(filter_parser.parse_value('before', Time.now)).to eq Time.now.to_s }
        it { expect(filter_parser.parse_value('contains', 'toto')).to eq '%toto%'}
        it { expect(filter_parser.parse_value('starts_with', 'a')).to eq 'a%'}
        it { expect(filter_parser.parse_value('ends_with', 'b')).to eq '%b' }
        it { expect(filter_parser.parse_value('not_contains', 'o')).to eq '%o%'}
        it { expect(filter_parser.parse_value('not_equal', 'test')).to eq 'test' }
        it { expect(filter_parser.parse_value('present', nil)).to eq nil }
        it { expect(filter_parser.parse_value('equal', 'yes')).to eq 'yes' }
        it { expect(filter_parser.parse_value('blank', nil)).to eq nil }
      end

      context 'on unknown operator' do
        it {
          expect {
            filter_parser.parse_value('bouygues', 76)
          }.to raise_error(ForestLiana::Errors::HTTP422Error, "Unknown provided operator 'bouygues'")
        }
      end
    end

    describe 'parse_field_name' do
      let(:resource) { Island }
      let(:result) { filter_parser.parse_field_name(field_name) }

      context 'on basic field' do
        context 'existing field' do
          let(:field_name) { 'name' }
          it { expect(result).to eq "\"isle\".\"name\""}
        end

        context 'not existing field' do
          let(:field_name) { 'gender' }
          it {
            expect { result }
              .to raise_error(ForestLiana::Errors::HTTP422Error, "Field '#{field_name}' not found")
          }
        end
      end

      context 'on belongs to field' do
        context 'existing field' do
          let(:field_name) { 'trees:age' }
          it { expect(result).to eq "\"trees\".\"age\""}
        end
        context 'not existing field' do
          let(:field_name) { 'hero:age' }
          it {
            expect { result }
              .to raise_error(ForestLiana::Errors::HTTP422Error, "Field '#{field_name}' not found")
          }
        end
        context 'not existing sub field' do
          let(:field_name) { 'trees:super_power' }
          it {
            expect { result }
              .to raise_error(ForestLiana::Errors::HTTP422Error, "Field '#{field_name}' not found")
          }
        end
      end
    end

    describe 'get_previous_interval_condition' do
      let(:result) { filter_parser.get_previous_interval_condition }

      context 'flat condition at root' do
        context 'has previous interval' do
          let(:filters) { date_condition_2 }
          it { expect(result).to eq date_condition_2 }
        end

        context 'has no previous interval' do
          let(:filters) { simple_condition_1 }
          it { expect(result).to eq nil }
        end
      end

      context "has 'and' aggregator" do
        let(:filters) { { 'aggregator' => 'and', 'conditions' => conditions } }

        context 'has no interval conditions' do
          let(:conditions) { [simple_condition_2, simple_condition_3] }
          it { expect(result).to eq nil }
        end

        context 'has nested conditions' do
          let(:conditions) { [date_condition_2, { 'aggregator' => 'and', 'conditions' => [simple_condition_2, simple_condition_3] }] }
          it { expect(result).to eq nil }
        end

        context 'has more than one interval condition' do
          let(:conditions) { [date_condition_2, date_condition_3] }
          it { expect(result).to eq nil }
        end

        context 'has only one interval condition' do
          let(:conditions) { [date_condition_2, simple_condition_1] }
          it { expect(result).to eq date_condition_2 }
        end
      end

      context "has 'or' aggregator" do
        let(:filters) { { 'aggregator' => 'or', 'conditions' => [date_condition_2, simple_condition_2] } }
        it { expect(result).to eq nil }
      end
    end

    describe 'apply_filters_on_previous_interval' do
      let(:filters) { { 'aggregator' => 'and', 'conditions' => [date_condition_2, simple_condition_1] } }

      it { expect(filter_parser.apply_filters_on_previous_interval(date_condition_2).count).to eq 1 }
    end
  end
end
