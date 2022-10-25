# Class for building db query based on params
class QueryBuilder

  def self.from (params)
    "SELECT * FROM #{ENV['ENVISIONWARE_TABLE_NAME']} #{where(params)} ORDER BY pcrDateTime ASC, pcrKey ASC #{self.limit};"
  end

  def self.where(params)
    "WHERE (pcrDateTime > '#{params[:pcr_date_time]}' OR (pcrDateTime = '#{params[:pcr_date_time]}' AND pcrKey > #{params[:pcr_key]}))"
  end

  def self.limit
    "LIMIT #{ENV['ENVISIONWARE_BATCH_SIZE']}"
  end

end
