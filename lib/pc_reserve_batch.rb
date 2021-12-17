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
    @patron_batch = Batcher.from(PatronBatch, @barcodes)
    @sierra_batch = Batcher.from(SierraBatch, @patron_batch.values.map { |patron| patron["id"].value })

    db_response.each do |row|
      begin
        $logger.debug("Processing row #{row}")
        pc_reserve = PcReserve.new row, @sierra_batch, @patron_batch
        pc_reserve.process
      rescue StandardError => e
        $logger.error("Error pushing pc reservation to Kinesis: #{e.message}")
        next
      end
    end

    begin
      $kinesis_client.push_records
    rescue StandardError => e
      $logger.error("Error pushing pc reservations to Kinesis: #{e.message}")
    end

    $logger.info "Finished processing records"
  end


end
