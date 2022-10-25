require 'nypl_ruby_util'

require_relative './safe_navigation_wrapper'

# A helper class for requesting a batch of patron data from Platform API
class PatronBatch

  def initialize(barcodes)
    @barcodes = barcodes
  end

  def get_resp
    # We should actually only be fetching one barcode at a time due to Platform limitations
    if @barcodes.length > 1
      $logger.error "#{$batch_id} More than one barcode in patron batch: #{@barcodes}"
    end

    barcode = @barcodes.first

    # These are guest passes and will not match anything in the patron db:
    if barcode.start_with? '25555'
      return [{ barcode: barcode, row: { "status" => "guest_pass"} }]
    end

    begin
      resp = $platform_client.get("#{ENV['PATRON_ENDPOINT']}?fields=id,barcodes,fixedFields,patronCodes&barcode=#{barcode}")
      resp["data"].map {|row| { barcode: barcode, row: row.merge({ "status" => "found" }) }}
    rescue StandardError => e
      $logger.info("#{$batch_id} Failed to fetch patron data for barcode #{barcode}", { error_message: e.message })
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
