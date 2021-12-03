require_relative './safe_navigation_wrapper'

# A helper class for requresting a batch of patron data from Platform

class PatronBatch

  def initialize(barcodes)
    @barcodes = barcodes
    @platform_client = ENV['APP_ENV'] == 'local' ?
      NYPLRubyUtil::PlatformApiClient.new( kms_options: { profile: ENV['AWS_PROFILE'] }) :
      NYPLRubyUtil::PlatformApiClient.new
  end

  def get_resp
    begin
      resp = @platform_client.get("#{ENV['PATRON_ENDPOINT']}?barcode=#{@barcodes.join(",")}")
      resp["data"].map {|row| { barcode: @barcodes.first, row: row }}   # Actually only fetching one barcode at a time
    rescue StandardError => e
      $logger.error("Failed to fetch patron data for ids #{@barcodes}")
      []
    end
  end

  def match_to_ids (resp)
    rows = resp.map do |row|
      [ row[:barcode], SafeNavigationWrapper.new(row[:row]) ]
    end
    rows.to_h
  end

  def self.batch_size
    ENV['PATRON_BATCH_SIZE']
  end

end
