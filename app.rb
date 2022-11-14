require "nypl_ruby_util"

require_relative 'lib/envisionware_db_client'
require_relative 'lib/pc_reserve_batch'
require_relative 'lib/query_builder'
require_relative 'lib/s3_client'
require_relative 'lib/sierra_db_client'
require_relative 'lib/state'

def load_env_vars
  config = File.readlines("./env_files/#{ENV["ENVIRONMENT"]}_env")
  config.each do |line|
    key_value_pair = line.split("=")
    ENV[key_value_pair[0]] = key_value_pair[1].chomp
  end
end

def init
  load_env_vars
  log_path = ENV['LOG_PATH'] || STDOUT
  $logger = NYPLRubyUtil::NyplLogFormatter.new(log_path, level: ENV['LOG_LEVEL'])

  $kinesis_client = NYPLRubyUtil::KinesisClient.new({
    :custom_aws_config => {
      region: ENV['S3_AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    },
    :schema_string => ENV['SCHEMA_TYPE'],
    :stream_name => ENV['KINESIS_STREAM_NAME'],
    :batch_size => ENV['KINESIS_BATCH_SIZE'].to_i,
    :partition_key => 'id'
  })

  $kms_client = NYPLRubyUtil::KmsClient.new({
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
  })

  $platform_client = NYPLRubyUtil::PlatformApiClient.new

  $sierra_db_client = SierraDbClient.new

  $envisionware_db_client = EnvisionwareDbClient.new

  $salt = $kms_client.decrypt(ENV['BCRYPT_SALT'])

  $logger.debug "Initialized function"
end

def handle_event(event:, context:)
  init

  begin
    $batch_number = 1
    finished = false
    while !finished
      # get the required db params from the current state if not configured locally
      if ENV['PCR_KEY_START'] && ENV['PCR_DATE_TIME_START'] && $batch_number == 1
        state_object = { "pcr_key" => ENV['PCR_KEY_START'], "pcr_date_time" => ENV['PCR_DATE_TIME_START'] }
        $state = State.new state_object
      elsif ENV['UPDATE_STATE'] != 'false'
        $state = State.from_s3 S3Client.fetch_current_state
      end
      pcr_key = $state.pcr_key
      pcr_date_time = $state.pcr_date_time

      $batch_id = "Time: #{Time.new.to_s}, key: #{pcr_key}"
      $logger.info('Begin batch', { id: $batch_id, number: $batch_number, size: ENV['ENVISIONWARE_BATCH_SIZE'] })

      # build and execute the query
      query  = QueryBuilder.from({ pcr_key: pcr_key, pcr_date_time: pcr_date_time })
      response = $envisionware_db_client.exec_query query
      
      if response.count > 0
        # process the results in kinesis
        pc_reserve_batch = PcReserveBatch.new response
        pc_reserve_batch.process

        # update the state unless this is a test run
        $state = State.from_db_result response
        unless ENV['UPDATE_STATE'] == 'false'
          $logger.info('Setting state: ', state: $state.json)
          S3Client.set_current_state $state.json
        end
      else
        $logger.info("#{$batch_id} No results for batch")
      end

      reached_max_batches = ENV['MAX_BATCHES'] && $batch_number >= ENV['MAX_BATCHES'].to_i

      if response.count >= ENV['ENVISIONWARE_BATCH_SIZE'].to_i && !reached_max_batches
        $batch_number += 1
        $logger.info("Finished batch #{$batch_id}, starting again")
      else
        finished = true
        $logger.info "#{$batch_id} Processing complete"
      end
    end

    $envisionware_db_client.close
    $sierra_db_client.close

  rescue StandardError => e
    $logger.error("Uncaught fatal error: ", { error_message: e.message })
  end
end
