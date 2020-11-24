module ForestLiana
  describe PermissionsGetter do
    describe '#get_permissions_api_route' do
      it 'should respond with the v3 permissions route' do
        expect(described_class.get_permissions_api_route).to eq '/liana/v3/permissions'
      end
    end

    # describe '#get_permissions_for_rendering' do
    #   # '/liana/v3/permissions'
    # end
  end
end
