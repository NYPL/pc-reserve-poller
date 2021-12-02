require 'pg'

# Client for managing connections to the PostgreSQL database
# Currently exposes a single method that allows executing an arbitraty query
class PSQLClient
    def initialize
        @conn = PG.connect(
            host: ENV['SIERRA_DB_HOST'],
            port: ENV['SIERRA_DB_PORT'],
            dbname: ENV['SIERRA_DB_NAME'],
            user: $kms_client.decrypt(ENV['SIERRA_DB_USER']),
            password: $kms_client.decrypt(ENV['SIERRA_DB_PSWD'])
        )
    end

    def exec_query(query)
        $logger.info 'Querying db'
        $logger.debug "Executing query: #{query}"

        begin
            @conn.exec_params query
        rescue StandardError => e
            $logger.error 'Unable to query db', { message: e.message }
            raise PSQLError, 'Cannot execute query against db, no rows retrieved'
        end
    end
end

class PSQLError < StandardError; end
