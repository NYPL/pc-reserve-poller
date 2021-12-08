require_relative './spec_helper'
require_relative '../lib/sierra_db_manager'


describe 'SierraDbClient' do

  before(:each) do
    $kms_client = double()
  end

  describe '#initialize' do
    it 'should set up PG connection with credentials' do
      client = double()
      allow($kms_client).to receive(:decrypt).with('fake_sierra_user').and_return('decrypted_user')
      allow($kms_client).to receive(:decrypt).with('fake_sierra_password').and_return('decrypted_password')
      allow(PG).to receive(:connect).with({
        host: 'fake_sierra_host',
        port: 'fake_sierra_port',
        dbname: 'fake_sierra_name',
        user: 'decrypted_user',
        password: 'decrypted_password'
      }).and_return client

      expect(SierraDbClient.new.instance_variable_get(:@conn)).to eql(client)
    end
  end

  describe '#ecex_query' do
    it 'should execute the query and return in case of no error' do
      client = double()
      allow($kms_client).to receive(:decrypt).with(anything())
      allow(PG).to receive(:connect).and_return client
      allow(client).to receive(:exec_params).and_return('OK response')
      expect(SierraDbClient.new.exec_query('Query')).to eql('OK response')
    end

    it 'should execute the query and raise SierraDbError in case of error' do
      client = double()
      allow($kms_client).to receive(:decrypt).with(anything())
      allow(PG).to receive(:connect).and_return client
      allow(client).to receive(:exec_params).and_raise(StandardError)
      expect { SierraDbClient.new.exec_query('Query') }.to raise_error(SierraDbError, 'Cannot execute query against db, no rows retrieved')
    end

  end

end
