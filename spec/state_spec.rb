require_relative './spec_helper'

describe 'state' do
  before(:each) do
    @test_state_object = { "pcr_date_time"=>'1900-01-01 00:00:00', "pcr_key" => 1 }
  end

  describe '#init' do
    it 'should set the state object' do
      state = State.new @test_state_object
      expect(state.state_object).to eql(@test_state_object)
    end
  end

  describe '#pcr_key' do
    it 'should get the pcr_key from the state object' do
      state = State.new @test_state_object
      expect(state.pcr_date_time).to eql('1900-01-01 00:00:00')
      expect(state.pcr_key).to eql(1)
    end
  end

  describe '#json' do
    it 'should get json from the state object' do
      state = State.new @test_state_object
      expect(state.json).to eql(@test_state_object.to_json)
    end
  end

  describe '#from_db_result' do
    it 'should return a state instance matching the db response' do
      state = State.from_db_result ([
        {"pcrDateTime"=>'1900-01-01 00:00:00', 'pcrKey' => 1},
        {"pcrDateTime"=>'1999-12-31 23:59:59', 'pcrKey' => 2}
      ])
      expect(state.pcr_date_time).to eql('1999-12-31 23:59:59')
      expect(state.pcr_key).to eql(2)
    end
  end

  describe 'from_s3' do
    it 'should return a state instance matching the s3 response' do
      state = State.from_s3(@test_state_object)
      expect(state.pcr_date_time).to eql('1900-01-01 00:00:00')
      expect(state.pcr_key).to eql(1)
    end
  end

end
