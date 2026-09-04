require 'rails_helper'

describe ForestLiana::ProjectionParser do
  def parse(header)
    described_class.new(header, 'Tree').perform
  end

  describe 'a well formed header' do
    it 'keys the bare columns on the root collection' do
      expect(parse('id,name')).to eq('Tree' => 'id,name')
    end

    it 'splits a relation path into the relation name and its own fields' do
      expect(parse('id,owner:name')).to eq('Tree' => 'id,owner', 'owner' => 'name')
    end

    it 'projects several fields on the same relation' do
      expect(parse('id,owner:name,owner:title')).to eq(
        'Tree' => 'id,owner',
        'owner' => 'name,title'
      )
    end

    it 'keeps the order of appearance and mentions a relation once' do
      expect(parse('name,owner:name,id,owner:id')).to eq(
        'Tree' => 'name,owner,id',
        'owner' => 'name,id'
      )
    end

    it 'ignores the whitespace around a path' do
      expect(parse('id, owner : name')).to eq('Tree' => 'id,owner', 'owner' => 'name')
    end
  end

  # NOTICE: A malformed header must not fall back to the full projection, or an agent that does
  #         not understand it would answer exactly like one that does.
  describe 'a malformed header' do
    it 'refuses an empty header' do
      expect { parse('') }.to raise_error(ForestLiana::Errors::HTTP400Error, /it is empty/)
    end

    it 'refuses a blank header' do
      expect { parse('   ') }.to raise_error(ForestLiana::Errors::HTTP400Error, /it is empty/)
    end

    it 'refuses an empty path' do
      expect { parse('id,,name') }.to raise_error(
        ForestLiana::Errors::HTTP400Error,
        /Malformed Forest-Projection header "id,,name": it holds an empty path/
      )
    end

    it 'names the path missing a field after the colon' do
      expect { parse('id,owner:') }.to raise_error(
        ForestLiana::Errors::HTTP400Error,
        %r{the path "owner:" names no field after ":"}
      )
    end

    it 'names the path missing a relation before the colon' do
      expect { parse('id,:name') }.to raise_error(
        ForestLiana::Errors::HTTP400Error,
        %r{the path ":name" names no relation before ":"}
      )
    end

    it 'names the path traversing more than one relation' do
      expect { parse('id,island:location:coordinates') }.to raise_error(
        ForestLiana::Errors::HTTP400Error,
        /the path "island:location:coordinates" traverses more than one relation/
      )
    end

    it 'answers a 400' do
      parse('id,,name')
    rescue ForestLiana::Errors::HTTP400Error => error
      expect(error.error_code).to eq 400
      expect(error.status).to eq :bad_request
    end
  end
end
