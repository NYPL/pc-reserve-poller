require 'aws-sdk-s3'
require 'json'
require 'net/https'
require 'uri'

# Class for getting and setting the state of the poller in S3
class S3Client

  def self.s3
    @@s3 ||= Aws::S3::Client.new(region: ENV['S3_AWS_REGION'])
  end

  # Load current state from S3 object
  def self.fetch_current_state
    # Fetch JSON object from S3
    begin
      status_uri = URI("#{ENV['S3_BASE_URL']}/#{ENV['S3_RESOURCE']}")
      $logger.debug "#{$batch_id} Fetching state from #{status_uri}"
      response = Net::HTTP.get_response(status_uri)
    rescue Exception => e
      $logger.error "#{$batch_id} Failed to load state file from S3", { :status => e.message }
      raise S3ClientError.new("Could not load file from S3")
    end

    # Confirm that a valid response was received
    unless response.code.to_i == 200
      $logger.error "#{$batch_id} Unable to load state from S3", { :status => response.body }
      raise S3ClientError.new("Unable to load state from S3 with error #{response.body}")
    end

    # Parse response into an object
    status_body = JSON.parse(response.body)

    $logger.debug "#{$batch_id} Fetched status #{status_body}"

    status_body
  end

  # Set new state values for given state. Invoked upon succesful parsing of a batch.
  # If this fails the function errors and records are retried from the previous position.
  def self.set_current_state(state_json)
    $logger.debug "#{$batch_id} Setting state #{state_json}"

    begin
      resp = s3.put_object({
        :body => state_json,
        :bucket => ENV['S3_BUCKET_NAME'],
        :key => ENV['S3_RESOURCE'],
        :acl => "public-read"
      })
    rescue Exception => e
      $logger.error "#{$batch_id} Unable to store current state record in S3", { :status => e.message }
      raise S3ClientError.new("Failed to store most recent state record in S3")
    end

  end

end

class S3ClientError < StandardError; end
