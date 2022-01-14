require 'nypl_ruby_util'

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
  $logger = NYPLRubyUtil::NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'])

  $kinesis_client = NYPLRubyUtil::KinesisClient.new({
        :schema_string => ENV['SCHEMA_TYPE'],
        :stream_name => ENV['KINESIS_STREAM'],
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
  init

  # get the required db params from the current state if not configured locally
  if ENV['CR_KEY_START']
    cr_key = ENV['CR_KEY_START']
  else
    current_state = State.from_s3 StateManager.fetch_current_state
    cr_key = current_state.cr_key
  end

  # build and execute the query
  query  = QueryBuilder.from({ cr_key: cr_key })
  response = EnvisionwareManager.new.exec_query query

  # process the results in kinesis
  pc_reserve_batch = PcReserveBatch.new response
  pc_reserve_batch.process


  # update the state unless this is a test run
  unless ENV['UPDATE_STATE'] == 'false'
    new_state = State.from_db_result response
    StateManager.set_current_state new_state.json
  end

  $logger.info "Processing complete"
end
