# A helper class for requesting a batch of data directly from the Sierra DB
class SierraBatch

  def initialize(ids)
    @ids = ids
  end

  def get_resp
    begin

      query = "SELECT patron_view.record_num,patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (#{@ids.join(",")});"

      sierra_result = $sierra_db_client.exec_query query
      $logger.debug("#{$batch_id} sierra result for #{@ids.join(",")}: #{sierra_result.values}")
      sierra_result

    rescue SierraDbError => e
      $logger.error "#{$batch_id} Error fetching Sierra Batch #{@ids}"
      []
    end
  end

  def match_to_ids(resp)
    rows = resp.map do |row|
      [ row["record_num"], row["postal_code"] ]
    end

    rows.to_h
  end

  def self.batch_size
    ENV['SIERRA_BATCH_SIZE'].to_i
  end


end
