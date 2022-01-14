require_relative './spec_helper'
require_relative '../lib/pc_reserve_batch'

describe 'PcReserveBatch' do

  describe '#process' do

    before(:each) do
      @db_response = [
        { "pcrUserID" => '123456789'},
        { "pcrUserID" => '233345678'},
        { "pcrUserID" => '233333333'},
        { "pcrUserID" => '000000000'},
      ]

      @expected_barcodes = [
        '123456789',
        '233345678',
        '233333333',
        '000000000'
      ]

      @expected_patron_ids = [ '1', '2', '3']

      @patron_batch = {
          '123456789' => SafeNavigationWrapper.new({ "id" => '1'}),
          '233345678' => SafeNavigationWrapper.new({ "id" => '2' }),
          '233333333' => SafeNavigationWrapper.new({ "id" => '3' })
      }
      allow(Batcher).to receive(:from).with(PatronBatch, @expected_barcodes).and_return(@patron_batch)
      @sierra_batch = double()
      allow(Batcher).to receive(:from).with(SierraBatch, @expected_patron_ids).and_return(@sierra_batch)
      @pc_reserve_batch = PcReserveBatch.new (@db_response)
      $kinesis_client = double()
      allow($kinesis_client).to receive(:push_records)
    end

    it 'should build a patron batch' do
      pc_reserve = double()
      allow(PcReserve).to receive(:new).and_return pc_reserve
      allow(pc_reserve).to receive(:process).and_return(nil)
      expect(Batcher).to receive(:from).with(PatronBatch, @expected_barcodes)
      @pc_reserve_batch.process
    end

    it 'should build a sierra batch' do
      pc_reserve = double()
      allow(PcReserve).to receive(:new).and_return pc_reserve
      allow(pc_reserve).to receive(:process).and_return(nil)
      expect(Batcher).to receive(:from).with(SierraBatch, @expected_patron_ids)
      @pc_reserve_batch.process
    end

    it 'should process each row' do
      pc_reserve_1 = double()
      pc_reserve_2 = double()
      pc_reserve_3 = double()
      pc_reserve_4 = double()
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '123456789'}, @sierra_batch, @patron_batch).and_return(pc_reserve_1)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '123456789'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_1).to receive(:process)
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '233345678'}, @sierra_batch, @patron_batch).and_return(pc_reserve_2)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '233345678'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_2).to receive(:process)
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '233333333'}, @sierra_batch, @patron_batch).and_return(pc_reserve_3)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '233333333'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_3).to receive(:process)
      allow(PcReserve).to receive(:new).with({"pcrUserID" => '000000000'}, @sierra_batch, @patron_batch).and_return(pc_reserve_4)
      expect(PcReserve).to receive(:new).with({"pcrUserID" => '000000000'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_4).to receive(:process)
      @pc_reserve_batch.process
    end

    it 'should rescue Avro Errors' do
      pc_reserve_1 = double()
      pc_reserve_2 = double()
      pc_reserve_3 = double()
      pc_reserve_4 = double()
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '123456789'}, @sierra_batch, @patron_batch).and_return(pc_reserve_1)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '123456789'}, @sierra_batch, @patron_batch)
      allow(pc_reserve_1).to receive(:process).and_raise(AvroError)
      expect(pc_reserve_1).to receive(:process)
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '233345678'}, @sierra_batch, @patron_batch).and_return(pc_reserve_2)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '233345678'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_2).to receive(:process)
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '233333333'}, @sierra_batch, @patron_batch).and_return(pc_reserve_3)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '233333333'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_3).to receive(:process)
      allow(PcReserve).to receive(:new).with({"pcrUserID" => '000000000'}, @sierra_batch, @patron_batch).and_return(pc_reserve_4)
      expect(PcReserve).to receive(:new).with({"pcrUserID" => '000000000'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_4).to receive(:process)
      allow($logger).to receive(:info).with("Finished processing records")
      expect($logger).to receive(:info).with("Finished processing records")
      @pc_reserve_batch.process
    end

    it 'should rescue NYPL errors' do
      pc_reserve_1 = double()
      pc_reserve_2 = double()
      pc_reserve_3 = double()
      pc_reserve_4 = double()
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '123456789'}, @sierra_batch, @patron_batch).and_return(pc_reserve_1)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '123456789'}, @sierra_batch, @patron_batch)
      allow(pc_reserve_1).to receive(:process).and_raise(NYPLError)
      expect(pc_reserve_1).to receive(:process)
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '233345678'}, @sierra_batch, @patron_batch).and_return(pc_reserve_2)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '233345678'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_2).to receive(:process)
      allow(PcReserve).to receive(:new).with({ "pcrUserID" => '233333333'}, @sierra_batch, @patron_batch).and_return(pc_reserve_3)
      expect(PcReserve).to receive(:new).with({ "pcrUserID" => '233333333'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_3).to receive(:process)
      allow(PcReserve).to receive(:new).with({"pcrUserID" => '000000000'}, @sierra_batch, @patron_batch).and_return(pc_reserve_4)
      expect(PcReserve).to receive(:new).with({"pcrUserID" => '000000000'}, @sierra_batch, @patron_batch)
      expect(pc_reserve_4).to receive(:process)
      allow($logger).to receive(:info).with("Finished processing records")
      expect($logger).to receive(:info).with("Finished processing records")
      @pc_reserve_batch.process
    end
  end


end
