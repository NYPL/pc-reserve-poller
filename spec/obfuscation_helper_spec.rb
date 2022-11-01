require_relative './spec_helper'
require_relative '../lib/obfuscation_helper'

describe 'ObfuscationHelper' do

  before(:each) do
    $salt = ENV['BCRYPT_SALT']
  end

  describe '#obfuscate' do
    it 'should encrypt the input string exactly as specified' do
      fake_hash = double()
      fake_password = double()
      inp = "super_duper_secret"
      allow(BCrypt::Engine).to receive(:hash_secret).and_return(fake_hash)
      allow(BCrypt::Password).to receive(:new).and_return(fake_password)
      allow(fake_password).to receive(:checksum).and_return('fake_encrypted')

      expect(BCrypt::Engine).to receive(:hash_secret).with(inp, ENV['BCRYPT_SALT'])
      expect(BCrypt::Password).to receive(:new).with(fake_hash)
      obfuscated = ObfuscationHelper.obfuscate(inp)
      expect(obfuscated).to eql('fake_encrypted')
    end
  end


end
