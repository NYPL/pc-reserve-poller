require_relative './spec_helper'
require_relative '../lib/batcher'

describe 'batcher' do
  describe '#from' do
    it 'should get responses in batches and merge them' do
      expect(Batcher.from(MockBatch, [0,1,2,3])).to eql({
          0 => 'x', 1 => 'y', 2 => 'z', 3 => 'w'
        })
    end

  end

end


class MockBatch

  def initialize(slice)
    @slice = slice
  end

  def get_resp
    if @slice == [0,1]
      [ { a: 0, b: 'x' }, { a: 1, b: 'y' } ]
    elsif @slice == [2,3]
      [ { a: 2, b: 'z' }, { a: 3, b: 'w' } ]
    end
  end

  def match_to_ids(resp)

    if resp == [ { a: 0, b: 'x' }, { a: 1, b: 'y' } ]
      { 0 => 'x', 1 => 'y' }
    elsif resp == [ { a: 2, b: 'z' }, { a: 3, b: 'w' } ]
      { 2 => 'z', 3 => 'w' }
    end
  end

  def self.batch_size
    2
  end

end
