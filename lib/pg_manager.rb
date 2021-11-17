require 'pg'

# Client for managing connections to the PostgreSQL database
# Currently exposes a single method that allows executing an arbitraty query
class PSQLClient
    def initialize
        @conn = PG.connect(
            host: ENV['DB_HOST'],
            port: ENV['DB_PORT'],
            dbname: ENV['DB_NAME'],
            user: $kms_client.decrypt(ENV['DB_USER']),
            password: $kms_client.decrypt(ENV['DB_PSWD'])
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
