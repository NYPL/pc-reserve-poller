require_relative './spec_helper'

describe 'query builder' do

  it 'should build the query from cr key' do
    expect(QueryBuilder.from( { cr_key: 10 })).to eql("SELECT * FROM #{ENV['TABLE_NAME']} WHERE pcrKey > 10;")
  end
end
