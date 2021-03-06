require 'rspec'
require 'mercury/received_message'

describe Mercury::ReceivedMessage do

  describe '#ack' do
    it 'raises an error if the message is not actionable' do
      expect{make_non_actionable.ack}.to raise_error /not ackable/
    end
    it 'raises an error if an action was already taken' do
      msg = make_actionable
      msg.reject
      expect { msg.ack }.to raise_error /already rejected/
    end
  end

  describe '#nack' do
    it 'raises an error if the message is not actionable' do
      expect{make_non_actionable.nack}.to raise_error /not nackable/
    end
    it 'raises an error if an action was already taken' do
      msg = make_actionable
      msg.ack
      expect { msg.nack }.to raise_error /already acked/
    end
  end

  describe '#reject' do
    it 'raises an error if the message is not actionable' do
      expect{make_non_actionable.reject}.to raise_error /not rejectable/
    end
    it 'raises an error if an action was already taken' do
      msg = make_actionable
      msg.nack
      expect { msg.reject }.to raise_error /already nacked/
    end
  end

  describe '#republish' do
    it 'calls Mercury#republish' do
      mercury_instance = double
      msg = Mercury::ReceivedMessage.new('hello', make_metadata, mercury_instance, work_queue_name: 'foo')
      cont = proc{}
      expect(mercury_instance).to receive(:republish) do |m, &k|
        expect(m).to eql msg
        expect(k).to eql cont
      end
      msg.republish(&cont)
    end
  end

  describe '#action_taken' do
    it 'returns the action taken' do
      a = make_actionable
      expect(a.action_taken).to eql nil

      b = make_actionable
      b.ack
      expect(b.action_taken).to eql :ack

      c = make_actionable
      c.nack
      expect(c.action_taken).to eql :nack

      d = make_actionable
      d.reject
      expect(d.action_taken).to eql :reject
    end
  end

  def make_actionable
    Mercury::ReceivedMessage.new('hello', make_metadata, double, work_queue_name: 'foo')
  end

  def make_non_actionable
    Mercury::ReceivedMessage.new('hello', make_metadata, double, work_queue_name: nil)
  end

  def make_metadata
    m = double
    allow(m).to receive(:ack)
    allow(m).to receive(:reject)
    m
  end
end
