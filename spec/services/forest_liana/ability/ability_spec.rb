module ForestLiana
  module Ability
    describe Ability do
      let(:dummy_class) { Class.new { extend ForestLiana::Ability } }
      let(:user) { { 'id' => '1', 'roleId' => '1' } }

      before do
        Island.create!(name: "L'île de la muerta")
      end

      describe 'forest authorize' do
        it 'should call is_crud_authorized? when the action is in [browse read edit add delete export] list' do
          allow_any_instance_of(ForestLiana::Ability::Permission).to receive(:is_crud_authorized?).and_return(true)
          %w[browse read edit add delete export].each do |action|
            expect(dummy_class.forest_authorize!(action, :user, Island.first)).to equal nil
          end
        end

        it 'should call is_chart_authorized? when the action equal chart' do
          allow_any_instance_of(ForestLiana::Ability::Permission).to receive(:is_chart_authorized?).and_return(true)
          expect(dummy_class.forest_authorize!('chart', :user, Island.first, {parameters: []})).to equal nil
        end

        it 'should raise error 422 on a chart action when the argument parameter is nil' do
          expect { dummy_class.forest_authorize!('chart', :user, Island.first) }.to raise_error(ForestLiana::Errors::HTTP422Error, "The argument parameters is missing")
        end

        it 'should call is_smart_action_authorized? when the action equal action' do
          allow_any_instance_of(ForestLiana::Ability::Permission).to receive(:is_smart_action_authorized?).and_return(true)
          expect(dummy_class.forest_authorize!('action', :user, Island.first, {parameters: [], endpoint: '...', http_method: 'POST'})).to equal true
        end

        it 'should raise error 422 on a chart smart-action when one or many arguments are missing' do
          expect { dummy_class.forest_authorize!('action', :user, Island.first) }.to raise_error(ForestLiana::Errors::HTTP422Error, "You must implement the arguments : parameters, endpoint & http_method")
        end

        it 'should raise access denied when the action is unknown' do
          expect { dummy_class.forest_authorize!('unknown', :user, Island.first) }.to raise_error(ForestLiana::Ability::Exceptions::AccessDenied, "You don't have permission to access this resource")
        end

        it 'should authorized user with correct permission_level to access charts' do
          user['permission_level'] = 'admin'
          expect(dummy_class.forest_authorize!('chart', user, Island.first, {parameters: []})).to equal nil
        end

        it 'should raise error 422 when the collection is nil on action ability' do
          expect { dummy_class.forest_authorize!('action', :user, nil) }.to raise_error(ForestLiana::Errors::HTTP422Error, "The conditional smart actions are not supported with Smart Collection. Please contact an administrator.")
        end

        it 'should raise error 422 when the collection is not a ActiveRecord children on action ability' do
          expect { dummy_class.forest_authorize!('action', :user, class Example; end ) }.to raise_error(ForestLiana::Errors::HTTP422Error, "The conditional smart actions are not supported with Smart Collection. Please contact an administrator.")
        end
      end
    end
  end
end
