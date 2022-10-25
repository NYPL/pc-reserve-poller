require 'mysql2'

# Client for managing connections to a MySQL database (in our case, the Envisionware DB).
# Currently exposes a single method that allows executing an arbitrary query.
class EnvisionwareDbClient

  def initialize
    begin
      @conn = Mysql2::Client.new(
        host: $kms_client.decrypt(ENV['ENVISIONWARE_DB_HOST']),
        port: ENV['ENVISIONWARE_DB_PORT'],
        database: ENV['ENVISIONWARE_DB_NAME'],
        username: $kms_client.decrypt(ENV['ENVISIONWARE_DB_USER']),
        password: $kms_client.decrypt(ENV['ENVISIONWARE_DB_PASSWORD'])
      )
    rescue StandardError => e
      $logger.error("Error connecting to Envisionware", { error_message: e.message })
      raise e
    end
  end

  def exec_query(query)
    $logger.info "#{$batch_id} Querying Envisionware db"
    $logger.debug "#{$batch_id} Executing query: #{query}"

    begin
      @conn.query query
    rescue StandardError => e
      $logger.error "#{$batch_id} Unable to query Envisionware db'", { error_message: e.message }
      raise EnvisionwareDbClientError, 'Cannot execute query against db, no rows retrieved'
    end
  end

  def close
    @conn.close
  end

end

class EnvisionwareDbClientError < StandardError; end
