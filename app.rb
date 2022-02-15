require "nypl_ruby_util"

require_relative 'lib/state_manager'
require_relative 'lib/query_builder'
require_relative 'lib/sierra_db_client'
require_relative 'lib/pc_reserve_batch'
require_relative 'lib/state'
require_relative 'lib/envisionware_manager'

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
        :stream_name => ENV['KINESIS_STREAM'],
        :batch_size => ENV['KINESIS_BATCH_SIZE'].to_i,
        :partition_key => 'id' }
  )

  $kms_client = NYPLRubyUtil::KmsClient.new(
    ENV['AWS_PROFILE'] ?
      { profile: ENV['AWS_PROFILE'] } :
      { access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'] }
  )

  $sierra_db_client = SierraDbClient.new

  $logger.debug "Initialized function"

end

def handle_event(event:, context:)
  begin
    $batch_number = 1
    finished = false
    while !finished
      init
      # get the required db params from the current state if not configured locally
      if ENV['CR_KEY_START']
        cr_key = ENV['CR_KEY_START']
      else
        current_state = State.from_s3 StateManager.fetch_current_state
        cr_key = current_state.cr_key
      end

      $batch_id = "Time: #{Time.new.to_s}, key: #{cr_key}"
      $logger.info('Begin batch', { id: $batch_id, number: $batch_number, size: ENV['BIC_SIZE'] })

      # build and execute the query
      query  = QueryBuilder.from({ cr_key: cr_key })
      envisionware_manager = EnvisionwareManager.new
      response = envisionware_manager.exec_query query


      # process the results in kinesis
      pc_reserve_batch = PcReserveBatch.new response
      pc_reserve_batch.process


      # update the state unless this is a test run
      unless ENV['UPDATE_STATE'] == 'false'
        new_state = State.from_db_result response
        StateManager.set_current_state new_state.json
      end

      envisionware_manager.close
      $sierra_db_client.close

      reached_max_batches = ENV['MAX_BATCHES'] && $batch_number >= ENV['MAX_BATCHES'].to_i

      if ENV['BIC_SIZE'] && response.count >= ENV['BIC_SIZE'].to_i && !reached_max_batches
        $batch_number += 1
        $logger.info("Finished batch #{$batch_id}, starting again")
      else
        finished = true
        $logger.info "#{$batch_id} Processing complete"
      end
    end
  rescue StandardError => e
    $logger.error("Uncaught fatal error: ", { message: e.message })
  end

end
