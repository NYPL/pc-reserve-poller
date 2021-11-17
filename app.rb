require 'nypl_ruby_util'

require_relative 'lib/state_manager'
require_relative 'lib/query_builder'
require_relative 'lib/pg_manager'
require_relative 'lib/patron_batch'
require_relative 'lib/state'

def init
  $logger = NYPLRubyUtil::NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'])

  $kinesis_client = NYPLRubyUtil::KinesisClient.new({
        :schema_string => ENV['SCHEMA_TYPE'],
        :stream_name => ENV['KINESIS_STREAM'],
        :partition_key => 'id' }
    )

  $kms_client = ENV['APP_ENV'] == 'local' ?
      NYPLRubyUtil::KmsClient.new({
          access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      }) : NYPLRubyUtil::KmsClient.new

  $logger.debug "Initialized function"
end

def handle_event(event:, context:)
  init

  # get the required db params from the current state
  current_state = State.from_s3 StateManager.fetch_current_state
  cr_key = current_state.cr_key

  # build and execute the query
  query  = QueryBuilder.from { cr_key: cr_key }
  response = PGManager.exec_query query

  # process the results in kinesis
  patron_batch = PatronBatch.new response
  patron_batch.process


  # update the state
  new_state = State.from_response response
  StateManager.set_current_state new_state.json

  $logger.info "Processing complete"
end
