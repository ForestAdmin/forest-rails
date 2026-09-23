require 'rails_helper'

# No collection in the dummy app is STI (Town < Location, but `locations` carries no type column,
# so is_sti_model? answers false everywhere) — the conversion is driven directly here rather than
# through a request, so the mechanism is pinned without a schema change whose only purpose would
# be to reach it.
describe 'converting a record to its STI collection class', type: :request do
  let(:record) do
    island = Island.create!(name: 'isle')
    Tree.create!(name: 'tree', island: island, owner: User.create!(name: 'owner'))
    Tree.where(name: 'tree').preload(:island).first
  end

  def convert(controller, resource_ivar, resource, subject = record)
    controller.instance_variable_set(resource_ivar, resource)
    allow(controller).to receive(:is_sti_model?).and_return(true)
    controller.send(:get_record, subject)
  end

  it 'carries what the getter preloaded through becomes, on the list' do
    expect(record.association(:island)).to be_loaded

    became = convert(ForestLiana::ResourcesController.new, :@resource, Tree)

    expect(became.association(:island)).to be_loaded

    # A dropped cache reads back the right value anyway — Rails just falls through to the lazy
    # belongs_to load — so the query is what has to be watched, not the value.
    queries = capture_queries { became.island }
    expect(queries).to be_empty
  end

  it 'carries it on the related list too' do
    controller = ForestLiana::AssociationsController.new
    controller.instance_variable_set(:@association, Island.reflect_on_association(:trees))
    allow(controller).to receive(:is_sti_model?).and_return(true)

    became = controller.send(:get_record, record)

    expect(became.association(:island)).to be_loaded
  end

  # preload_polymorphic_associations attaches its targets as singleton readers, and becomes()
  # allocates an instance whose singleton class is empty — so those readers are lost here. The
  # targets are not: Rails' Preloader fills the association cache for a polymorphic relation too,
  # and that is what crosses. Pinned because the two are easy to conflate, and because an STI
  # collection holding a polymorphic to-one would otherwise keep a per-row query on this path.
  it 'carries a preloaded polymorphic target, which rides in the association cache' do
    user = User.create!(name: 'resident')
    address = Address.create!(line1: '1 Palm Street', city: 'Papeete', zipcode: '00000', addressable: user)
    records = Address.where(id: address.id).to_a
    ForestLiana::BaseGetter.allocate.send(:preload_polymorphic_associations, records, [:addressable])

    became = convert(ForestLiana::ResourcesController.new, :@resource, Address, records.first)

    # Captured around the *first* read, and uncached: a dropped attachment falls through to the
    # lazy polymorphic load, which answers the right value either way — and the SELECT it issues
    # is the one the preload already ran, so the query cache would swallow the very query that
    # proves the attachment was lost.
    queries = capture_queries { ActiveRecord::Base.uncached { expect(became.addressable).to eq(user) } }
    expect(queries).to be_empty
  end

  # An association proxy carries the reflection of the class that built it, and association(name)
  # never re-checks it against the class the record has just become. Town narrows its parent's
  # `island` with a scope of its own, so a blanket copy would serve the subclass's (empty) target
  # under the base class's field — right shape, wrong value, nothing raised.
  it 'leaves behind an entry the two classes do not define identically' do
    island = Island.create!(name: 'isle')
    town = Town.where(id: Town.create!(island_id: island.id).id).preload(:island).first

    expect(town.island).to be_nil

    became = convert(ForestLiana::ResourcesController.new, :@resource, Location, town)

    expect(became.association(:island)).not_to be_loaded
    expect(became.island).to eq(island)
  end
end
