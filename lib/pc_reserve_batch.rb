require_relative './batcher'
require_relative './patron_batch'
require_relative './pc_reserve'
require_relative './sierra_batch'

# Wrapper for pushing to Kinesis
class PcReserveBatch

  attr_accessor :envisionware_db_response

  def initialize (envisionware_db_response)
    @envisionware_db_response = envisionware_db_response
    @barcodes = envisionware_db_response.map { |row| row["pcrUserID"] } # The pcrUserID is a barcode
  end

  def process
    # patron_map is a map with a barcode (equivalent to an Envisionware pcrUserId) as a key and patron data from Platform as a value
    $logger.info("#{$batch_id} Querying Platform")
    @patron_map = Batcher.from(PatronBatch, @barcodes)
    patrons_missing_ids = @patron_map.keys.select { |patron_barcode| !@patron_map[patron_barcode]["id"] }
    if !patrons_missing_ids.empty?
      $logger.warn("#{$batch_id} Patron barcodes missing Platform ids: #{patrons_missing_ids}")
    end
    patron_ids = @patron_map.values.map { |patron| patron["id"].value }

    # sierra_map is a map with a Sierra record_num (equivalent to a Platform patron id) as a key and patron data from Sierra as a value
    @sierra_map = Batcher.from(SierraBatch, patron_ids.compact)
    patrons_missing_sierra_info = @sierra_map.keys.select {
      |record_num| !@sierra_map[record_num][:patron_record_id] || !@sierra_map[record_num][:postal_code]
    }
    if !patrons_missing_sierra_info.empty?
      $logger.warn("#{$batch_id} Platform ids missing Sierra info: #{patrons_missing_sierra_info}")
    end

    envisionware_db_response.each do |row|
      begin
        $logger.debug("#{$batch_id} Processing row #{row}")
        pc_reserve = PcReserve.new row, @sierra_map, @patron_map
        pc_reserve.process
      rescue StandardError => e
        $logger.error("#{$batch_id} Error shovelling pc reservation to Kinesis: #{e.message}")
        next
      end
    end

    begin
      $kinesis_client.push_records
    rescue StandardError => e
      $logger.error("#{$batch_id} Error pushing pc reservations to Kinesis: #{e.message}")
    end

    $logger.info "#{$batch_id} Finished processing records"
  end

end
