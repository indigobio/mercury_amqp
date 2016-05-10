require 'spec_helper'
require 'mercury/wire_serializer'

describe Mercury::WireSerializer do
  subject { Mercury::WireSerializer.new }
  describe '#write' do
    it 'writes a string hash as JSON' do
      expect(subject.write('a' => 1)).to eql '{"a":1}'
    end
    it 'writes a symbol hash as JSON' do
      expect(subject.write(a: 1)).to eql '{"a":1}'
    end
    it 'writes a struct as JSON' do
      Foo = Struct.new(:a)
      expect(subject.write(Foo.new(1))).to eql '{"a":1}'
    end
    it 'writes a string literally' do
      expect(subject.write('asdf')).to eql 'asdf'
    end
  end
  describe '#read' do
    it 'reads JSON as a string hash' do
      expect(subject.read('{"a":1}')).to eql('a' => 1)
    end
    it 'reads unparseable JSON as a string' do
      expect(subject.read('asdf')).to eql 'asdf'
    end
  end
end
