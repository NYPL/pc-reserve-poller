require_relative './pc_reserve'
require_relative './patron_batch'
require_relative './sierra_batch'
require_relative './batcher'


# Wrapper for pushing to Kinesis

class PcReserveBatch
  attr_accessor :db_response, :process_statuses

  def initialize (db_response)
    @db_response = db_response
    @barcodes = db_response.map { |row| row["pcrUserID"] } # the pcrUserID is a barcode
  end

  def process
    $logger.debug("#{$batch_id} Patron Batch for #{@barcodes}")
    @patron_batch = Batcher.from(PatronBatch, @barcodes)
    patrons_missing_ids = @patron_batch.keys.select {|patron_key| !@patron_batch[patron_key]["id"] }
    if !patrons_missing_ids.empty?
      $logger.warn("#{$batch_id} Patrons missing ids #{patrons_missing_ids}")
    end
    patron_ids = @patron_batch.values.map { |patron| patron["id"].value }
    $logger.debug("#{$batch_id} Sierra Batch for #{patron_ids}")
    @sierra_batch = Batcher.from(SierraBatch, patron_ids.compact)

    db_response.each do |row|
      begin
        $logger.debug("#{$batch_id} Processing row #{row}")
        pc_reserve = PcReserve.new row, @sierra_batch, @patron_batch
        pc_reserve.process
      rescue StandardError => e
        $logger.error("#{$batch_id} Error pushing pc reservation to Kinesis: #{e.message}")
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
