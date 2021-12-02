require_relative './spec_helper'
require_relative '../lib/patron'

describe 'patron' do


  describe '#new' do
    it 'should set id' do
      patron = Patron.new(123456)
      expect(patron.id).to eql(123456)
    end
  end

  describe '#get_data' do
    it 'should make a request to platform' do
      patron = Patron.new(123456)
      client = double()
      allow(Patron).to receive(:platform_client).and_return(client)
      allow(client).to receive(:get).and_return({ "data" => "fake_data" })
      expect(client).to receive(:get).with("#{ENV['PATRON_ENDPOINT']}/123456")
      patron.get_data
    end

    it 'should set data if data received' do
      patron = Patron.new(123456)
      client = double()
      allow(Patron).to receive(:platform_client).and_return(client)
      allow(client).to receive(:get).and_return({ "data" => "fake_data" })
      patron.get_data
      expect(patron.data).to eql('fake_data')
    end

    it 'should raise Patron Error in case of error' do
      patron = Patron.new(123456)
      client = double()
      allow(Patron).to receive(:platform_client).and_return(client)
      allow(client).to receive(:get).and_raise(StandardError.new('Fake Error message'))
      expect{ patron.get_data }.to raise_error(PatronError, 'Error fetching patron 123456')
    end
  end

  describe '#from' do
    it 'should make a request to platform' do
      id = 123456
      client = double()
      allow(Patron).to receive(:platform_client).and_return(client)
      allow(client).to receive(:get).and_return({ "data" => "fake_data" })
      expect(client).to receive(:get).with("#{ENV['PATRON_ENDPOINT']}/123456")
      Patron.from(id)
    end

    it 'should raise Patron Error in case of error' do
      id = 123456
      client = double()
      allow(Patron).to receive(:platform_client).and_return(client)
      allow(client).to receive(:get).and_raise(StandardError.new('Fake Error message'))
      expect { Patron.from(id) }.to raise_error(PatronError, 'Error fetching patron 123456')
    end

    it 'should return wrapped data in case of success' do
      id = 123456
      client = double()
      allow(Patron).to receive(:platform_client).and_return(client)
      allow(client).to receive(:get).and_return({ "data" => "fake_data" })
      expect(Patron.from(id).class).to eql(SafeNavigationWrapper)
      expect(Patron.from(id).value).to eql("fake_data")
    end
  end

  describe '#platform_client' do
    it 'should set and return @@platform_client with configured credentials' do
      mock_client = double()
      allow(NYPLRubyUtil::PlatformApiClient).to receive(:new).and_return(mock_client)
      client = Patron.platform_client
      expect(client).to eql(mock_client)
      expect(Patron.class_variable_get(:@@platform_client)).to eql(mock_client)
    end
  end
end
