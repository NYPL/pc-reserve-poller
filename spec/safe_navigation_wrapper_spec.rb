require_relative './spec_helper'
require_relative '../lib/safe_navigation_wrapper'

describe 'SafeNavigationWrapper' do

  describe '#new and #value' do
    it 'should set and get the value correctly' do
      expect((SafeNavigationWrapper.new 'fake').value).to eql('fake')
    end
  end

  describe '#[]' do
    it 'should get attribute from hash or array' do
      from_array = (SafeNavigationWrapper.new [1,2,3])[1]
      expect(from_array.class).to eql(SafeNavigationWrapper)
      expect(from_array.value).to eql(2)
      from_hash = (SafeNavigationWrapper.new({ a: 1, b: 2 }))[:b]
      expect(from_hash.class).to eql(SafeNavigationWrapper)
      expect(from_hash.value).to eql(2)
    end

    it 'should return wrapped nil in case no attribute' do
      from_string = (SafeNavigationWrapper.new 'string')[:b]
      expect(from_string.class).to eql(SafeNavigationWrapper)
      expect(from_string.value).to eql(nil)
      from_nil = (SafeNavigationWrapper.new nil)[:b]
      expect(from_string.class).to eql(SafeNavigationWrapper)
      expect(from_string.value).to eql(nil)
    end

  end



end
