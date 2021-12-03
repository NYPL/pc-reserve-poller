require_relative './pc_reserve'
require_relative './patron_batch'
require_relative './sierra_batch'
require_relative './batcher'


# Wrapper for pushing to Kinesis

class PcReserveBatch
  attr_accessor :db_response, :process_statuses

  def initialize (db_response)
    @db_response = db_response
    @process_statuses = { :success => 0, :error => 0 }
    @barcodes = db_response.map { |row| row["pcrUserID"] } # the pcrUserID is a barcode
  end

  def process
    @patron_batch = Batcher.from(PatronBatch, @barcodes)
    @sierra_batch = Batcher.from(SierraBatch, @patron_batch.values.map { |patron| patron["id"].value })

    matched_responses = db_response.filter { |row| @patron_batch[row["pcrUserID"]] }
    matched_responses.each do |row|
      begin
        $logger.debug("Processing row #{row}")
        pc_reserve = PcReserve.new row, @sierra_batch, @patron_batch
        pc_reserve.process
      rescue AvroError => e
        $logger.warn "Failed avro validation for row #{row}", { :status => e.message }
        @process_statuses[:error] += 1
        next
      rescue NYPLError => e
        $logger.warn "Record failed to write to kinesis", { :status => e.message }
        @process_statuses[:error] += 1
        next
      end

      $logger.info "Successfully processed Record"
      @process_statuses[:success] += 1
    end

    $logger.info "Successfully processed #{process_statuses[:success]} records, with #{process_statuses[:error]} errors"
  end


end
