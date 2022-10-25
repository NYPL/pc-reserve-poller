require_relative './spec_helper'
require_relative '../lib/sierra_batch'
require_relative '../lib/sierra_db_client'

describe 'SierraBatch' do

  describe '#get_resp' do
    before(:each) do
      @ids = [1,2,3]
      $sierra_db_client = double()
      @sierra_batch = SierraBatch.new @ids
      allow($logger).to receive(:debug)
    end

    it 'should make the correct query' do
      @successful_response = double()
      allow(@successful_response).to receive(:values).and_return([])
      allow($sierra_db_client).to receive(:exec_query).with("SELECT patron_view.record_num, patron_view.id AS patron_record_id, patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (1,2,3);").and_return @successful_response
      expect($sierra_db_client).to receive(:exec_query).with("SELECT patron_view.record_num, patron_view.id AS patron_record_id, patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (1,2,3);")
      @sierra_batch.get_resp
    end

    it 'should return response in case of successful query' do
      @successful_response = double()
      allow(@successful_response).to receive(:values).and_return([])
      allow($sierra_db_client).to receive(:exec_query).with("SELECT patron_view.record_num, patron_view.id AS patron_record_id, patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (1,2,3);").and_return @successful_response
      expect(@sierra_batch.get_resp).to eql(@successful_response)
    end

    it 'should return [] in case of errors' do
      allow($sierra_db_client).to receive(:exec_query).with("SELECT patron_view.record_num, patron_view.id AS patron_record_id, patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (1,2,3);").and_raise SierraDbClientError
      expect(@sierra_batch.get_resp ).to eql([])
    end
  end

  describe '#match_to_ids' do

    it 'should return a mapping of postal codes to record numbers' do
      @resp = [
        { "record_num" => 1, "patron_record_id" => '4', "postal_code" => "code1"},
        { "record_num" => 2, "patron_record_id" => '5', "postal_code" => "code2"},
        { "record_num" => 3, "patron_record_id" => '6', "postal_code" => "code3"},
      ]
      @matched = {
        1 => {:patron_record_id => '4', :postal_code => "code1"},
        2 => {:patron_record_id => '5', :postal_code => "code2"},
        3 => {:patron_record_id => '6', :postal_code => "code3"}
      }
      @sierra_batch = SierraBatch.new([])
      expect(@sierra_batch.match_to_ids(@resp)).to eql(@matched)
    end
  end

  describe '#batch_size' do
    it 'should get the configured batch size' do
      expect(SierraBatch.batch_size).to eql(1)
    end
  end

end
