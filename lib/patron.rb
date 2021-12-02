require 'nypl_ruby_util'
require_relative './safe_navigation_wrapper'


# Wrapper class for patrons fetched from the Patron Service

class Patron
  attr_accessor :data, :id


  def initialize (id)
    @id = id
  end

  def get_data
    begin
      resp = Patron.platform_client.get("#{ENV['PATRON_ENDPOINT']}/#{id}")
      self.data = resp["data"]
    rescue StandardError => e
      $logger.error("Failed to fetch patron data for #{id}", e.message)
      raise PatronError.new("Error fetching patron #{id}")
    end
  end


  def self.from (id)
    patron = Patron.new id
    patron.get_data
    SafeNavigationWrapper.new patron.data
  end

  def self.platform_client
    @@platform_client ||= ENV['APP_ENV'] == 'local' ?
      # NYPLRubyUtil::PlatformApiClient.new( kms_options: { access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'] }) :
      NYPLRubyUtil::PlatformApiClient.new( kms_options: { profile: ENV['AWS_PROFILE'] }) :
      NYPLRubyUtil::PlatformApiClient.new
  end

end


class PatronError < StandardError; end
