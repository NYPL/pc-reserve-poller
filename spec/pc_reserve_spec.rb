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
        "pcrUserData1" => "staff_override",
        "pcrKey" => "aaaaa"
      }
      @sierra_batch = { "1" => "postal_code" }

      # allow(ObfuscationHelper).to receive(:obfuscate).and_return('12345')
      allow(ObfuscationHelper).to receive(:obfuscate) do |arg|
        if arg.start_with? 'barcode'
          '6789'
        else
          '12345'
        end
      end

      $kinesis_client = double()
      allow($kinesis_client).to receive(:<<)
      @patron_batch = double()

      allow(@patron_batch).to receive(:[]).with('123456789').and_return (SafeNavigationWrapper.new({
        'id' => '1',
        'fixedFields' => {
          '47' => { 'value' => '2'},
          '53' => { 'value' => 'library_code    '},
        },
        'patronCodes' => {
          'pcode3' => 'p',
        },
        'status' => 'found'
      }))

      allow(@patron_batch).to receive(:[]).with('255556789').and_return (SafeNavigationWrapper.new({
          'status' => 'guest_pass'
      }))
    end

    it 'should push the right data to kinesis' do


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
          staff_override: "staff_override",
          patron_retrieval_status: "found"
      })
      @pc_reserve.process
    end

    it 'should fall back to defaults for missing patron' do

      @missing_data = {
        "pcrUserID" => "255556789",
        "pcrMinutesUsed" => "minutes",
        "pcrDateTime" => Date.new(2021, 1, 1),
        "pcrBranch" => "branch",
        "pcrArea" => "area",
        "pcrUserData1" => "staff_override",
        "pcrKey" => "aaaaa"
      }


      @pc_reserve = PcReserve.new(@missing_data, @sierra_batch, @patron_batch)

      expect($kinesis_client).to receive(:<<).with({
        :area=>"area",
        :branch=>"branch",
        :geoid=>nil,
        :key=>"12345",
        :minutes_used=>"minutes",
        :patron_home_library_code=>nil,
        :patron_id=>"6789",
        :pcode3=>nil,
        :postal_code=>nil,
        :ptype_code=>nil,
        :staff_override=>"staff_override",
        :transaction_et=>"2021-01-01",
        :patron_retrieval_status => "guest_pass"
      })

      @pc_reserve.process

    end
  end

end
