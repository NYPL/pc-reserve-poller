require_relative './spec_helper'
require_relative '../lib/envisionware_db_client'

describe 'EnvisionwareDbClient' do
  before(:each) do
    $kms_client = double()
  end

  describe '#initialize' do
    it 'should set up MySql2 client with credentials' do
      client = double()
      allow($kms_client).to receive(:decrypt).with('fake_envisionware_user').and_return('decrypted_user')
      allow($kms_client).to receive(:decrypt).with('fake_envisionware_password').and_return('decrypted_password')
      allow($kms_client).to receive(:decrypt).with('fake_envisionware_host').and_return('decrypted_host')
      allow(Mysql2::Client).to receive(:new).with({
          host: 'decrypted_host',
          port: 'fake_envisionware_port',
          database: 'fake_envisionware_name',
          username: 'decrypted_user',
          password: 'decrypted_password'
        }).and_return(client)

      expect(EnvisionwareDbClient.new.instance_variable_get(:@conn)).to eql(client)
    end
  end

  describe '#exec_query' do
    it 'should execute the query and return in case of no error' do
      client = double()
      allow($kms_client).to receive(:decrypt).with(anything())
      allow(Mysql2::Client).to receive(:new).and_return(client)
      allow(client).to receive(:query).and_return('OK response')
      expect(EnvisionwareDbClient.new.exec_query('Query')).to eql('OK response')
    end

    it 'should execute the query and raise EnvisionwareDbClientError in case of error' do
      client = double()
      allow($kms_client).to receive(:decrypt).with(anything())
      allow(Mysql2::Client).to receive(:new).and_return(client)
      allow(client).to receive(:query).and_raise(StandardError)
      expect {
          db_client = EnvisionwareDbClient.new
          db_client.exec_query('Query')
      }.to raise_error(EnvisionwareDbClientError, 'Cannot execute query against db, no rows retrieved')
    end

  end

end
