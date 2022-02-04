require 'nypl_ruby_util'
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
    barcode = @barcodes.first # Actually only fetching one barcode at a time

    # these are guest passes and will not match anything in the patron db:
    if barcode.start_with? '25555'
      return [{ barcode: barcode, row: { "status" => "guest_pass"} }]
    end

    begin
      resp = @platform_client.get("#{ENV['PATRON_ENDPOINT']}?fields=id,barcodes,fixedFields,patronCodes&barcode=#{barcode}")
      resp["data"].map {|row| { barcode: barcode, row: row.merge({ "status" => "found" }) }}
    rescue StandardError => e
      $logger.error("#{$batch_id} Failed to fetch patron data for ids #{@barcodes}")
      [{ barcode: barcode, row: { "status" => "missing" } }]
    end
  end

  def match_to_ids (resp)
    rows = resp.map do |row|
      [ row[:barcode], SafeNavigationWrapper.new(row[:row]) ]
    end
    rows.to_h
  end

  def self.batch_size
    ENV['PATRON_BATCH_SIZE'].to_i
  end

end
