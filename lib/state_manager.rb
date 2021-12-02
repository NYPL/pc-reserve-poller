require 'aws-sdk-s3'
require 'json'
require 'net/https'
require 'uri'


# Class for managing the state of the poller in S3
class StateManager

    def self.s3
      @@s3 ||= Aws::S3::Client.new(region: ENV['S3_AWS_REGION'])
    end

    # Load current state from S3 object
    def self.fetch_current_state
        # Fetch JSON object from S3
        begin
            status_uri = URI("#{ENV['S3_BASE_URL']}/#{ENV['BUCKET_NAME']}/#{ENV['SCHEMA_TYPE'].downcase}_poller_status.json")
            $logger.debug "Fetching state from #{status_uri}"
            response = Net::HTTP.get_response(status_uri)
        rescue Exception => e
            $logger.error "Failed to load state file from S3", { :status => e.message }
            raise S3Error.new("Could not load file from S3")
        end

        # Confirm that a valid response was received
        unless response.code.to_i == 200
            $logger.error "Unable to load state from S3", { :status => response.body }
            raise S3Error.new("Unable to load state from S3 with error #{response.body}")
        end

        # Parse response into an object
        status_body = JSON.parse(response.body)

        $logger.debug "Fetched status #{status_body}"

        status_body
    end

    # Set new state values for given state. Invoked upon succesful parsing of a batch
    def self.set_current_state(state_json)
        $logger.debug "Setting state #{state_json}"

        # Send object to S3.
        # If this fails the function errors and records are retried from the previous position
        begin
            resp = s3.put_object({
                :body => state_json,
                :bucket => ENV['BUCKET_NAME'],
                :key => "#{ENV['SCHEMA_TYPE'].downcase}_poller_status.json",
                :acl => "public-read"
            })
        rescue Exception => e
            $logger.error "Unable to store current state record in S3", { :status => e.message }
            raise S3Error.new("Failed to store most recent state record in S3")
        end

    end
end


class S3Error < StandardError; end
