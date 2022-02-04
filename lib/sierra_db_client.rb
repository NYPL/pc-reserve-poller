require 'pg'

# Client for managing connections to the PostgreSQL database
# Currently exposes a single method that allows executing an arbitraty query
class SierraDbClient
    def initialize
        @conn = PG.connect(
            host: $kms_client.decrypt(ENV['SIERRA_DB_HOST']),
            port: ENV['SIERRA_DB_PORT'],
            dbname: ENV['SIERRA_DB_NAME'],
            user: $kms_client.decrypt(ENV['SIERRA_DB_USER']),
            password: $kms_client.decrypt(ENV['SIERRA_DB_PSWD'])
        )
    end

    def exec_query(query)
        $logger.info "#{$batch_id} Querying db"
        $logger.debug "#{$batch_id} Executing query: #{query}"

        begin
            @conn.exec_params query
        rescue StandardError => e
            $logger.error "#{$batch_id} Unable to query db", { message: e.message }
            raise SierraDbError, 'Cannot execute query against db, no rows retrieved'
        end
    end

    def close
      @conn.close
    end
end

class SierraDbError < StandardError; end
