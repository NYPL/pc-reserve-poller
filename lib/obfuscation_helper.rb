require 'bcrypt'


class ObfuscationHelper
  def self.obfuscate (string)
    hash = BCrypt::Engine.hash_secret string, $kms_client.decrypt(ENV['BCRYPT_SALT'])
    BCrypt::Password.new(hash).checksum
  end
end
