# A helper class for requesting data  in batches


class Batcher

  def initialize(type, ids)
    @type = type
    @ids = ids
  end

  def process
    responses = @ids.each_slice(@type.batch_size.to_i).map do |slice|
      batch = @type.new slice
      resp = batch.get_resp
      batch.match_to_ids resp
    end

    responses.reduce do |acc, el|
      acc.merge el
    end

  end


  def self.from(type, ids)
    batch = Batcher.new(type, ids)
    batch.process
  end


end
