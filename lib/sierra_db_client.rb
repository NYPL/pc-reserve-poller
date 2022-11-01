require 'pg'

# Client for managing connections to a PostgreSQL database (in our case, the Sierra DB).
# Currently exposes a single method that allows executing an arbitrary query.
class SierraDbClient

  def initialize
    begin
      @conn = PG.connect(
        host: $kms_client.decrypt(ENV['SIERRA_DB_HOST']),
        port: ENV['SIERRA_DB_PORT'],
        dbname: ENV['SIERRA_DB_NAME'],
        user: $kms_client.decrypt(ENV['SIERRA_DB_USER']),
        password: $kms_client.decrypt(ENV['SIERRA_DB_PASSWORD'])
      )
    rescue StandardError => e
      $logger.error("Error connecting to Sierra", { error_message: e.message })
      raise e
    end
  end

  def exec_query(query)
    $logger.info "#{$batch_id} Querying Sierra db"
    $logger.debug "#{$batch_id} Executing query: #{query}"

    begin
      @conn.exec_params query
    rescue StandardError => e
      $logger.error "#{$batch_id} Unable to query Sierra db", { error_message: e.message }
      raise SierraDbClientError, 'Cannot execute query against db, no rows retrieved'
    end
  end

  def close
    @conn.close
  end

end

class SierraDbClientError < StandardError; end
