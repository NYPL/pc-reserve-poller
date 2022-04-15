# Class for building db query based on params

class QueryBuilder

  def self.from (params)
    "SELECT * FROM #{ENV['TABLE_NAME']} #{where(params)} ORDER BY pcrDateTime ASC, pcrKey ASC#{self.limit};"
  end

  def self.where(params)
    "WHERE (pcrDateTime > #{params[:pcr_date_time]} OR (pcrDateTime = #{params[:pcr_date_time]} AND pcrKey > #{params[:cr_key]}))"
  end

  def self.limit
    ENV['BIC_SIZE'] ? " LIMIT #{ENV['BIC_SIZE']}" : ''
  end

end
