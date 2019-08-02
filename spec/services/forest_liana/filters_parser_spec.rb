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
    let(:date_condition_1) { { 'field' => 'created_at', 'operator' => 'before', 'value' => 2.hours.ago } }
    let(:date_condition_2) { { 'field' => 'created_at', 'operator' => 'today' } }
    let(:date_condition_3) { { 'field' => 'created_at', 'operator' => 'previous_x_days', 'value' => 2 } }

    before {
      island = Island.create!(name: "L'île de la muerta")
      king = User.create!(title: :king, name: 'Ben E.')
      villager = User.create!(title: :villager)
      Tree.create!(name: 'Tree n1', age: 1, island: island, owner: king)
      Tree.create!(name: 'Tree n2', age: 3, island: island, created_at: 3.day.ago, owner: king)
      Tree.create!(name: 'Tree n3', age: 4, island: island, owner: king, cutter: villager)
    }

    after {
      Tree.destroy_all
      User.destroy_all
      Island.destroy_all
    }

    describe 'initialization' do
      context 'badly formated filters' do
        let(:filter_parser) { described_class.new('{ toto: 1', resource, timezone) }

        it {
          expect {
            described_class.new('{ toto: 1', resource, timezone)
          }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Invalid filters JSON format')
        }
      end
    end

    describe 'apply_filters' do
      let(:parsed_filters) { filter_parser.apply_filters }

      context 'on valid filters' do
        context 'single condtions' do
          context 'not_equal' do
            let(:filters) { { field: 'age', operator: 'not_equal', value: 4 } }
            it { expect(parsed_filters.count).to eq 2 }
          end

          context 'equal' do
            let(:filters) { { field: 'age', operator: 'equal', value: 4 } }
            it { expect(parsed_filters.count).to eq 1 }
          end

          context 'greater_than' do
            let(:filters) { { field: 'age', operator: 'greater_than', value: 2 } }
            it { expect(parsed_filters.count).to eq 2 }
          end

          context 'less_than' do
            let(:filters) { { field: 'age', operator: 'less_than', value: 2 } }
            it { expect(parsed_filters.count).to eq 1 }
          end

          context 'after' do
            let(:filters) { { field: 'created_at', operator: 'after', value: 1.day.ago } }
            it { expect(parsed_filters.count).to eq 2 }
          end

          context 'before' do
            let(:filters) { { field: 'created_at', operator: 'before', value: 1.day.ago } }
            it { expect(parsed_filters.count).to eq 1 }
          end

          context 'contains' do
            let(:filters) { { field: 'name', operator: 'contains', value: 'ree' } }
            it { expect(parsed_filters.count).to eq 3 }
          end

          context 'not_contains' do
            let(:filters) { { field: 'name', operator: 'not_contains', value: ' ' } }
            it { expect(parsed_filters.count).to eq 0 }
          end

          context 'starts_with' do
            let(:filters) { { field: 'name', operator: 'starts_with', value: 'o' } }
            it { expect(parsed_filters.count).to eq 0 }
          end

          context 'ends_with' do
            let(:filters) { { field: 'name', operator: 'ends_with', value: '3' } }
            it { expect(parsed_filters.count).to eq 1 }
          end

          context 'present' do
            let(:filters) { { field: 'cutter_id', operator: 'present', value: nil } }
            it { expect(parsed_filters.count).to eq 1 }
          end

          context 'blank' do
            let(:filters) { { field: 'cutter_id', operator: 'blank', value: nil } }
            it { expect(parsed_filters.count).to eq 2 }
          end
        end

        context 'belongsTo conditions' do
          context 'not_equal' do
            let(:filters) { { field: 'cutter:title', operator: 'not_equal', value: 'king' } }
            it { expect(parsed_filters.count).to eq 1 }
          end

          context 'equal' do
            let(:filters) { { field: 'cutter:title', operator: 'equal', value: 'king' } }
            it { expect(parsed_filters.count).to eq 0 }
          end

          context 'contains' do
            let(:filters) { { field: 'owner:title', operator: 'contains', value: 'in' } }
            it { expect(parsed_filters.count).to eq 3 }
          end

          context 'not_contains' do
            let(:filters) { { field: 'owner:title', operator: 'not_contains', value: 'g' } }
            it { expect(parsed_filters.count).to eq 0 }
          end

          context 'starts_with' do
            let(:filters) { { field: 'cutter:title', operator: 'starts_with', value: 'v' } }
            it { expect(parsed_filters.count).to eq 1 }
          end

          context 'two belongsTo' do
            context 'different fields' do
              let(:filters) {
                {
                  aggregator: 'or', conditions: [
                    { field: 'owner:name', operator: 'contains', value: 'E.' },
                    { field: 'cutter:title', operator: 'starts_with', value: 'v' }
                  ]
                }
              }
              it { expect(parsed_filters.count).to eq 3 }
            end

            context 'same fields' do
              let(:filters) {
                {
                  aggregator: 'and', conditions: [
                    { field: 'owner:name', operator: 'contains', value: 'E.' },
                    { field: 'owner:title', operator: 'starts_with', value: 'v' }
                  ]
                }
              }
              it { expect(parsed_filters.count).to eq 3 }
            end
          end
        end

        context 'and aggregator on simple conditions' do
          let(:filters) { { aggregator: 'and', conditions: [simple_condition_1, simple_condition_2] } }
          it { expect(parsed_filters.count).to eq 1 }
        end


        context 'complex conditions' do
          context 'and aggregator on simple conditions' do
            let(:filters) {
              {
                aggregator: 'or',
                conditions: [
                  { aggregator: 'and', conditions: [
                    { aggregator: 'or', conditions: [date_condition_1, simple_condition_1] },
                    simple_condition_2
                  ] },
                  { field: 'cutter:title', operator: 'starts_with', value: 'v' }
                ]
              }
            }
            it { expect(parsed_filters.count).to eq 1 }
          end
        end
      end

      context 'on invalid filters' do
        context 'invalid condition format' do
          let(:filters) { { toto: 'Why nut?' } }
          it {
            expect { parsed_filters }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Invalid condition format')
          }
        end

        context 'array as filter' do
          let(:filters) { [] }
          it {
            expect { parsed_filters }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Filters cannot be a raw value')
          }
        end

        context 'empty filter' do
          let(:filters) { { } }
          it {
            expect { parsed_filters }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Empty condition in filter')
          }
        end

        context 'raw value in conditions' do
          let(:filters) { { aggregator: 'and', conditions: [4] } }
          it {
            expect { parsed_filters }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Filters cannot be a raw value')
          }
        end

        context 'bad field type' do
          let(:filters) { { field: 4, operator: 'oss 117', value: 'tuorp' } }
          it {
            expect { parsed_filters }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Invalid condition format')
          }
        end

        context 'bad operator type' do
          let(:filters) { { field: 'magnetic', operator: true, value: 'tuorp' } }
          it {
            expect { parsed_filters }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Invalid condition format')
          }
        end

        context 'unexisting field' do
          let(:filters) { { field: 'magnetic', operator: 'archer', value: 'tuorp' } }
          it {
            expect { parsed_filters }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Field \'magnetic\' not found')
          }
        end
      end
    end

    describe 'parse_aggregation' do
      let(:query) { filter_parser.parse_aggregation(filters) }

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

    describe 'parse_aggregation_operator' do
      context 'on valid aggregator' do
        it { expect(filter_parser.parse_aggregation_operator('and')).to eq 'AND' }
        it { expect(filter_parser.parse_aggregation_operator('or')).to eq 'OR' }
      end

      context 'on unknown aggregator' do
        it {
          expect {
            filter_parser.parse_aggregation_operator('sfr')
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
        it { expect(filter_parser.parse_operator 'not_contains').to eq 'NOT LIKE' }
        it { expect(filter_parser.parse_operator 'not_equal').to eq '!=' }
        it { expect(filter_parser.parse_operator 'present').to eq 'IS NOT' }
        it { expect(filter_parser.parse_operator 'equal').to eq '=' }
        it { expect(filter_parser.parse_operator 'blank').to eq 'IS' }
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
        let(:now) { Time.now }
        it { expect(filter_parser.parse_value('not', true)).to eq true }
        it { expect(filter_parser.parse_value('greater_than', 34)).to eq 34 }
        it { expect(filter_parser.parse_value('after', now)).to eq now }
        it { expect(filter_parser.parse_value('less_than', 45)).to eq 45 }
        it { expect(filter_parser.parse_value('before', now)).to eq now }
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
      let(:filters) { { 'aggregator' => 'and', 'conditions' => [date_condition_3, simple_condition_1] } }

      it { expect(filter_parser.apply_filters_on_previous_interval(date_condition_3).count).to eq 1 }
    end
  end
end
