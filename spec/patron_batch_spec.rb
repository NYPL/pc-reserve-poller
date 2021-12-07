require_relative './spec_helper'
require_relative '../lib/patron_batch'

describe 'PatronBatch' do

  describe '#initialize' do
    it 'should set @barcode and @platform_client when initialized' do \
      barcodes = double()
      platform_client = double()
      allow(NYPLRubyUtil::PlatformApiClient).to receive(:new).and_return(platform_client)
      patron_batch = PatronBatch.new(barcodes)
      expect(patron_batch.instance_variable_get(:@barcodes)).to eql(barcodes)
      expect(patron_batch.instance_variable_get(:@platform_client)).to eql(platform_client)
    end
  end

  describe '#get_resp' do
    before(:each) do
      @barcodes = double()
      @platform_client = double()
      allow(NYPLRubyUtil::PlatformApiClient).to receive(:new).and_return(@platform_client)
      @patron_batch = PatronBatch.new(@barcodes)
    end

    it 'should make correct query to patron endpoint' do
      allow(@barcodes).to receive(:join).and_return('1')
      allow(@barcodes).to receive(:first).and_return('1')
      expect(@platform_client).to receive(:get).with('http://www.fake_patron.com?barcode=1')
      @patron_batch.get_resp
    end

    it 'should return array of barcode, row pairs in case of successful db query' do
      allow(@barcodes).to receive(:join).and_return('1')
      allow(@barcodes).to receive(:first).and_return('1')
      allow(@platform_client).to receive(:get).with('http://www.fake_patron.com?barcode=1').and_return({ "data" => [{ a: 'b', c: 'd'}]})
      expect(@patron_batch.get_resp).to eql([{ barcode: '1', row: { a: 'b', c: 'd'} }])
    end

    it 'should return [] in case of errors' do
      allow(@barcodes).to receive(:join).and_return('1')
      allow(@barcodes).to receive(:first).and_return('1')
      allow(@platform_client).to receive(:get).with('http://www.fake_patron.com?barcode=1').and_raise StandardError
      expect(@patron_batch.get_resp).to eql([])
    end
  end

  describe '#match_to_ids' do
    before(:each) do
      @barcodes = double()
      @platform_client = double()
      allow(NYPLRubyUtil::PlatformApiClient).to receive(:new).and_return(@platform_client)
      @patron_batch = PatronBatch.new(@barcodes)
    end

    it 'should take an array of barcode, row pairs and return a hash of barcodes mapping to wrapped rows' do
      matched = @patron_batch.match_to_ids([
        { barcode: '1', row: [1,2,3]},
        { barcode: '2', row: [4,5,6]}
      ])

      expect(matched.class).to eql(Hash)
      expect(matched.keys).to eql(["1", "2"])
      expect(matched["1"].class).to eql(SafeNavigationWrapper)
      expect(matched["1"].value).to eql([1,2,3])
      expect(matched["2"].class).to eql(SafeNavigationWrapper)
      expect(matched["2"].value).to eql([4,5,6])
    end
  end

  describe '#batch_size' do
    it 'should get the configured batch size' do
      expect(PatronBatch.batch_size).to eql('123')
    end
  end

end
