require 'nypl_ruby_util'

require_relative 'lib/state_manager'
require_relative 'lib/query_builder'
require_relative 'lib/sierra_db_client'
require_relative 'lib/pc_reserve_batch'
require_relative 'lib/state'
require_relative 'lib/envisionware_manager'

def init
  $logger = NYPLRubyUtil::NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'])

  $kinesis_client = NYPLRubyUtil::KinesisClient.new({
        :schema_string => ENV['SCHEMA_TYPE'],
        :stream_name => ENV['KINESIS_STREAM'],
        :partition_key => 'id' }
    )

  $kms_client = ENV['APP_ENV'] == 'local' ?
      NYPLRubyUtil::KmsClient.new(
        { profile: ENV['AWS_PROFILE'] }
      ) : NYPLRubyUtil::KmsClient.new

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
