require 'spec_helper'
require 'mercury/utils'

Utils = Mercury::Utils

describe Utils do
  describe '::unsplat' do
    it 'allows args to be provided in splatted form' do
      expect(Utils.unsplat([])).to eql []
      expect(Utils.unsplat([1])).to eql [1]
      expect(Utils.unsplat([1, 2])).to eql [1, 2]
    end
    it 'allows args to be provided as an array' do
      expect(Utils.unsplat([[]])).to eql []
      expect(Utils.unsplat([[1]])).to eql [1]
      expect(Utils.unsplat([[1, 2]])).to eql [1, 2]
    end
  end
end
