require 'bcrypt'

class ObfuscationHelper

  def self.obfuscate (string)
    BCrypt::Password.new(
      BCrypt::Engine.hash_secret string, $salt
    ).checksum
  end

end
