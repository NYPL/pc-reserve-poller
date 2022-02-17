require 'bcrypt'


class ObfuscationHelper
  def self.obfuscate (string)
    BCrypt::Password.new(
      BCrypt::Engine.hash_secret string, $kms_client.decrypt(ENV['BCRYPT_SALT'])
    ).checksum
  end
end
