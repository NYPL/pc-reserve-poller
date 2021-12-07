require_relative './spec_helper'
require_relative '../lib/sierra_batch'
require_relative '../lib/pg_manager'

describe 'SierraBatch' do


  describe '#get_resp' do
    before(:each) do
      @ids = [1,2,3]
      $pg_manager = double()
      @sierra_batch = SierraBatch.new @ids
    end

    it 'should make the correct query' do
      allow($pg_manager).to receive(:exec_query).with("SELECT patron_view.record_num,patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (1,2,3);")
      expect($pg_manager).to receive(:exec_query).with("SELECT patron_view.record_num,patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (1,2,3);")
      @sierra_batch.get_resp
    end

    it 'should return response in case of successful query' do
      @successful_response = double()
      allow($pg_manager).to receive(:exec_query).with("SELECT patron_view.record_num,patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (1,2,3);").and_return @successful_response
      expect(@sierra_batch.get_resp).to eql(@successful_response)
    end

    it 'should return [] in case of errors' do
      allow($pg_manager).to receive(:exec_query).with("SELECT patron_view.record_num,patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (1,2,3);").and_raise PSQLError
      expect(@sierra_batch.get_resp ).to eql([])
    end
  end

  describe '#match_to_ids' do

    it 'should return a mapping of postal codes to record numbers' do
      @resp = [
        { "record_num" => 1, "postal_code" => "code1"},
        { "record_num" => 2, "postal_code" => "code2"},
        { "record_num" => 3, "postal_code" => "code3"},
      ]
      @matched = {
        1 => "code1",
        2 => "code2",
        3 => "code3"
      }
      @sierra_batch = SierraBatch.new([])
      expect(@sierra_batch.match_to_ids(@resp)).to eql(@matched)
    end
  end

  describe '#batch_size' do
    it 'should get the configured batch size' do
      expect(SierraBatch.batch_size).to eql('1')
    end
  end


end
