require_relative './spec_helper'
require_relative '../app'


describe 'handler' do
    describe '#init' do
        before(:each) {
            @kms_mock = double()
            allow(@kms_mock).to receive(:decrypt)
            allow(NYPLRubyUtil::KmsClient).to receive(:new).and_return(@kms_mock)
            @kinesis_mock = double()
            allow(NYPLRubyUtil::KinesisClient).to receive(:new).and_return(@kinesis_mock)
            @s3_mock = double()
            allow(Aws::S3::Client).to receive(:new).and_return(@s3_mock)
            @platform_mock = double()
            allow(NYPLRubyUtil::PlatformApiClient).to receive(:new).and_return(@platform_mock)
        }

        it "should invoke clients and logger from the ruby utils gem" do
            init

            expect($kms_client).to eq(@kms_mock)
            expect($kinesis_client).to eq(@kinesis_mock)
        end
     end

    describe '#handle_event' do

        # check interaction with external services
        # S3
        # DB 1
        # DB 2
        # Kinesis
        # S3 again
        it "should invoke the StateManager and Sierra manager to process records" do
        end
    end
end
