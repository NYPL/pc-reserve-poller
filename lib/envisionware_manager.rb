require 'mysql2'

# Client for managing connections to a MySQL database (in our case, the Envisionware DB)
# Currently exposes a single method that allows executing an arbitraty query

class EnvisionwareManager

  def initialize
    @client = Mysql2::Client.new(
      host: ENV['ENVISIONWARE_HOST'],
      port: ENV['ENVISIONWARE_PORT'],
      database: ENV['ENVISIONWARE_NAME'],
      username: $kms_client.decrypt(ENV['ENVISIONWARE_USER']),
      password: $kms_client.decrypt(ENV['ENVISIONWARE_PASSWORD'])
    )
  end

  def exec_query(query)
      $logger.info 'Querying Envisionware db'
      $logger.debug "Executing query: #{query}"

      begin
          @client.query query
      rescue StandardError => e
          $logger.error 'Unable to query envisionware db', { message: e.message }
          raise EnvisionwareManagerError, 'Cannot execute query against db, no rows retrieved'
      end
  end

end

class EnvisionwareManagerError < StandardError; end
