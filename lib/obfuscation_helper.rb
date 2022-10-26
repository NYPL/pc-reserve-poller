require 'bcrypt'

# A helper class for obfuscating data using bcrypt
class ObfuscationHelper

  def self.obfuscate (string)
    BCrypt::Password.new(
      BCrypt::Engine.hash_secret string, $salt
    ).checksum
  end

end
