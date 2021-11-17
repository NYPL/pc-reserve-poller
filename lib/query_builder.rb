# Class for building db query based on params

class QueryBuilder

  def self.from (params)
    "SELECT * FROM #{ENV['TABLE_NAME']} WHERE pcrKey > #{params[:cr_key]};"
  end

end
