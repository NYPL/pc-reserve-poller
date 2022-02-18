# Wrapper for respresentation of lambda state
require 'pry'

class State

  attr_accessor :state_object

  def initialize (state_object)
    @state_object = state_object
  end

  def cr_key
    state_object["cr_key"]
  end

  def json
    state_object.to_json
  end

  def self.from_db_result (db_response)
    state_object = extract_state_from_db_response db_response
    State.new state_object
  end

  def self.from_s3 (s3_response)
    state_object = extract_state_from_s3_response s3_response
    State.new state_object
  end

  def self.extract_state_from_db_response (db_response)
    last_element = db_response.lazy.drop(db_response.count  - 1).first
    last_key = last_element["pcrKey"]
    $logger.error('Missing pcrKey', db_response: db_response.to_a) if !last_key
    # binding.pry if !last_key
    { "cr_key" => last_key }
  end

  def self.extract_state_from_s3_response (s3_response)
    s3_response
  end

end
