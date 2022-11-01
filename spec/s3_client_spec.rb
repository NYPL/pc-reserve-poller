require_relative './spec_helper'
require_relative '../lib/s3_client'

describe S3Client do

  before(:each) do
    @s3_stub = double()
    allow(Aws::S3::Client).to receive(:new).and_return(@s3_stub)
  end

  describe '#s3' do
    it 'should set s3 with configured region' do
      expect(Aws::S3::Client).to receive(:new).with({ region: ENV['S3_AWS_REGION']})
      s3 = S3Client.s3
      expect(s3).to eql(@s3_stub)
      expect(S3Client.class_variable_get(:@@s3)).to eql(@s3_stub)
    end
  end

  describe '#fetch_current_state' do

    success_response = OpenStruct.new (
      {
        code: 200,
        body: "\"fake_body\""
      }
    )

    failure_response = OpenStruct.new(
      {
        code: 500,
        body: ""
      }
    )

    it 'should query the correct endpoint' do
      allow(Net::HTTP).to receive(:get_response).and_return(success_response)
      expect(Net::HTTP).to receive(:get_response).with(URI("#{ENV['S3_BASE_URL']}/#{ENV['S3_RESOURCE']}"))
      S3Client.fetch_current_state
    end

    it 'should return the status if possible' do
      allow(Net::HTTP).to receive(:get_response).and_return(success_response)
      resp = S3Client.fetch_current_state
      expect(resp).to eql("fake_body")
    end

    it 'should raise an S3ClientError if the response code isn\'t 200' do
      allow(Net::HTTP).to receive(:get_response).and_return(failure_response)
      expect { S3Client.fetch_current_state }.to raise_error(S3ClientError, "Unable to load state from S3 with error ")
    end

    it 'should raise an S3ClientError if there is any error fetching the s3 file' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError)
      expect { S3Client.fetch_current_state }.to raise_error(S3ClientError, "Could not load file from S3")
    end
  end

end
