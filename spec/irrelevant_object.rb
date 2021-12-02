# Useful for avoiding errors in tests due to objects that are not part of the test

class Irrelevant

  def method_missing(name, *args, &block)
  end

end
