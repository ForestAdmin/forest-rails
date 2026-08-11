module ForestLiana
  describe Model::Action do
    def action_with(endpoint)
      Model::Action.new(name: 'an action', endpoint: endpoint)
    end

    describe 'endpoint routing' do
      it 'defaults to an endpoint under the mount, with or without a leading slash' do
        action = Model::Action.new(name: 'an action')

        expect(action.endpoint).to eq('forest/actions/an-action')
        expect(action.endpoint_under_forest_mount?).to be true
        expect(action.engine_relative_endpoint).to eq('/actions/an-action')

        expect(action_with('/forest/actions/foo').endpoint_under_forest_mount?).to be true
        expect(action_with('/forest/actions/foo').engine_relative_endpoint).to eq('/actions/foo')
      end

      it 'routes an endpoint outside the mount on the host, verbatim' do
        action = action_with('/domains/organizations/suspensions/suspend')

        expect(action.endpoint_under_forest_mount?).to be false
        expect(action.absolute_endpoint).to eq('/domains/organizations/suspensions/suspend')
      end

      # `sub('forest', '')` used to match anywhere, mangling these into '/ry/actions/x' and '/my//x'.
      it 'does not treat a path merely containing "forest" as being under the mount' do
        expect(action_with('forestry/actions/x').endpoint_under_forest_mount?).to be false
        expect(action_with('forestry/actions/x').absolute_endpoint).to eq('/forestry/actions/x')

        expect(action_with('my/forest/x').endpoint_under_forest_mount?).to be false
        expect(action_with('my/forest/x').absolute_endpoint).to eq('/my/forest/x')
      end
    end
  end
end
