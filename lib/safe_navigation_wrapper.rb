# A wrapper to reduce boilerplate from defensive coding

class SafeNavigationWrapper

  def initialize (value)
    @value = value
  end

  def [] (key)
    begin
      SafeNavigationWrapper.new @value[key]
    rescue StandardError
      SafeNavigationWrapper.new nil
    end
  end

  def value
    @value
  end

end
