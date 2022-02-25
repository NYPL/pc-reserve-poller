require 'mysql2'

# Client for managing connections to a MySQL database (in our case, the Envisionware DB)
# Currently exposes a single method that allows executing an arbitraty query

class EnvisionwareManager

  def initialize
    @client = Mysql2::Client.new(
      host: $kms_client.decrypt(ENV['ENVISIONWARE_HOST']),
      port: ENV['ENVISIONWARE_PORT'],
      database: ENV['ENVISIONWARE_NAME'],
      username: $kms_client.decrypt(ENV['ENVISIONWARE_USER']),
      password: $kms_client.decrypt(ENV['ENVISIONWARE_PASSWORD'])
    )
  end

  def exec_query(query)
      $logger.info "#{$batch_id} Querying Envisionware db"
      $logger.info "#{$batch_id} Executing query: #{query}"

      begin
          @client.query query
      rescue StandardError => e
          $logger.error "#{$batch_id} Unable to query envisionware db'", { error_message: e.message }
          raise EnvisionwareManagerError, 'Cannot execute query against db, no rows retrieved'
      end
  end

  def close
    @client.close
  end

end

class EnvisionwareManagerError < StandardError; end
