require_relative './spec_helper'

describe 'query builder' do

  it 'should build the query from pcr key' do
    expect(QueryBuilder.from( {pcr_date_time: '2021-01-01 00:00:00', pcr_key: 10 }))
      .to eql("SELECT * FROM #{ENV['ENVISIONWARE_TABLE_NAME']}"\
        " WHERE (pcrDateTime > '2021-01-01 00:00:00' OR (pcrDateTime = '2021-01-01 00:00:00' AND pcrKey > 10))"\
        " ORDER BY pcrDateTime ASC, pcrKey ASC LIMIT #{ENV['ENVISIONWARE_BATCH_SIZE']};")
  end

end
