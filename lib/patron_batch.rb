require_relative './patron'


# Wrapper for pushing to Kinesis

class PatronBatch
  attr_accessor :db_response, :process_statuses

  def initialize (db_response)
    @db_response = db_response
    @process_statuses = { :success => 0, :error => 0 }
  end


  def initialize_events
  end

  def process
    db_response.each do |row|
      begin
        patron = Patron.new row
        patron.process
      rescue AvroError => e
        $logger.warn "Failed avro validation", { :status => e.message }
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
