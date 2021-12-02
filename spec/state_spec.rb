require_relative './spec_helper'


describe 'state' do
  before(:each) do
    @test_state_object = { cr_key: 'test' }
  end

  describe '#init' do
    it 'should set the state object' do
      state = State.new @test_state_object
      expect(state.state_object).to eql(@test_state_object)
    end
  end

  describe '#cr_key' do
    it 'should get the cr_key from the state object' do
      state = State.new @test_state_object
      expect(state.cr_key).to eql('test')
    end
  end

  describe '#json' do
    it 'should get json from the state object' do
      state = State.new @test_state_object
      expect(state.json).to eql(@test_state_object.to_json)
    end
  end

  describe '#from_db_result' do
    it 'should return a state instance matching the s3 response' do
      state = State.from_db_result ([ { 'pcrKey' => 1}, { 'pcrKey' => 2} ])
      expect(state.cr_key).to eql(2)
    end
  end

  describe 'from_s3' do
    it 'should return a state instance matching the s3 response' do
      state = State.from_s3({ cr_key: 1 })
      expect(state.cr_key).to eql(1)
    end
  end

  describe '#extract_state_from_db_response' do
    it 'should return an object with the cr_key from the db response\'s pcrKey' do
      obj = State.extract_state_from_db_response ([ { 'pcrKey' => 1}, { 'pcrKey' => 2} ])
      expect(obj).to eql({ :cr_key => 2})
    end
  end

  describe 'extract_state_from_s3_response' do
    it 'should return an object matching the s3 response' do
      obj = State.extract_state_from_s3_response({ cr_key: 1 })
      expect(obj).to eql({ cr_key: 1 })
    end
  end

end
