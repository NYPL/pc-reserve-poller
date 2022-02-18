# Class for building db query based on params

class QueryBuilder

  def self.from (params)
    "SELECT pcrUserID, pcrKey FROM #{ENV['TABLE_NAME']} WHERE pcrKey > #{params[:cr_key]}#{self.limit};"
  end

  def self.limit
    ENV['BIC_SIZE'] ? " LIMIT #{ENV['BIC_SIZE']}" : ''
  end

end
