# A helper class for requesting a batch of data directly from the Sierra DB
class SierraBatch

  def initialize(ids)
    @ids = ids
  end

  def get_resp
    begin
      query = "SELECT patron_view.record_num, patron_view.id AS patron_record_id, patron_record_address.postal_code" +
        " FROM sierra_view.patron_view LEFT OUTER JOIN sierra_view.patron_record_address ON patron_record_address.patron_record_id=patron_view.id" +
        " WHERE patron_view.record_num IN (#{@ids.join(",")})" +
        " ORDER BY patron_view.record_num, patron_record_address.display_order, patron_record_address.patron_record_address_type_id;"

      sierra_result = $sierra_db_client.exec_query query
      $logger.debug("#{$batch_id} sierra result for #{@ids.join(",")}: #{sierra_result.values}")
      sierra_result.values.uniq(&:first)

    rescue SierraDbClientError => e
      $logger.error "#{$batch_id} Error fetching Sierra Batch #{@ids}"
      []
    end
  end

  def match_to_ids(resp)
    rows = resp.map do |row|
      [ row[0], { postal_code: row[2], patron_record_id: row[1] } ]
    end

    rows.to_h
  end

  def self.batch_size
    ENV['SIERRA_BATCH_SIZE'].to_i
  end

end
