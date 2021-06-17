module ForestLiana
  describe Bootstrapper do
    describe 'setup_forest_liana_meta' do
      it "should put statistic data related to user stack on a dedicated object" do
        expect(ForestLiana.meta[:stack])
          .to include(:orm_version)
        expect(ForestLiana.meta[:stack])
          .to include(:database_type)
      end
    end
  end
end
