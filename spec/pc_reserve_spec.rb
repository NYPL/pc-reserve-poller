require_relative './spec_helper'
require_relative '../lib/pc_reserve'
require_relative '../lib/safe_navigation_wrapper'

describe 'PcReserve' do

  describe '#process' do
    before(:each) do
      @data = {
        "pcrUserID" => "123456789",
        "pcrMinutesUsed" => "minutes",
        "pcrDateTime" => Date.new(2021, 1, 1),
        "pcrBranch" => "branch",
        "pcrArea" => "area",
        "pcrUserData1" => "staff_override"
      }
      @sierra_batch = { "1" => "postal_code" }

      allow(ObfuscationHelper).to receive(:obfuscate).and_return('12345')
      $kinesis_client = double()
      allow($kinesis_client).to receive(:<<)
    end

    it 'should push the right data to kinesis' do
      @patron_batch = { '123456789' => SafeNavigationWrapper.new({
          'id' => '1',
          'fixedFields' => {
            '47' => { 'value' => '2'},
            '53' => { 'value' => 'library_code    '},
          },
          'patronCodes' => {
            'pcode3' => 'p',
          }
      })}


      @pc_reserve = PcReserve.new(@data, @sierra_batch, @patron_batch)

      expect($kinesis_client).to receive(:<<).with({
          patron_id: '12345',
          ptype_code: 2,
          patron_home_library_code: 'library_code',
          pcode3: 'p',
          postal_code: "postal_code",
          geoid: nil,
          key: '12345',
          minutes_used: "minutes",
          transaction_et: "2021-01-01" ,
          branch: "branch",
          area: "area",
          staff_override: "staff_override"
      })
      @pc_reserve.process
    end

    it 'should fall back to defaults for missing patron' do

      @patron_batch = {}


      @pc_reserve = PcReserve.new(@data, @sierra_batch, @patron_batch)

      expect($kinesis_client).to receive(:<<).with({
        :area=>"area",
        :branch=>"branch",
        :geoid=>nil,
        :key=>"12345",
        :minutes_used=>"minutes",
        :patron_home_library_code=>nil,
        :patron_id=>nil,
        :pcode3=>nil,
        :postal_code=>nil,
        :ptype_code=>nil,
        :staff_override=>"staff_override",
        :transaction_et=>"2021-01-01"
      })

      @pc_reserve.process

    end
  end

end
