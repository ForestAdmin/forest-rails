describe 'forest_liana.gemspec' do
  let(:gemspec) { Gem::Specification.load(File.expand_path('../../../forest_liana.gemspec', __dir__)) }
  let(:json_requirement) { gemspec.runtime_dependencies.find { |dependency| dependency.name == 'json' }.requirement }

  it 'accepts the json 2 line' do
    expect(json_requirement).to be_satisfied_by(Gem::Version.new('2.21.2'))
  end

  it 'refuses json 3, which older ActiveSupport versions cannot call' do
    expect(json_requirement).not_to be_satisfied_by(Gem::Version.new('3.0.0'))
    expect(json_requirement).not_to be_satisfied_by(Gem::Version.new('3.1.0'))
  end
end
