require 'spec_helper'
require 'mercury/sync'
require 'mercury/monadic'

describe Mercury::Sync do
  include Cps::Methods
  let!(:source) { 'test-exchange1' }
  let!(:queue) { 'test-queue1' }
  let(:headers) { {'X-Domain-Variable' => 'value'} }
  describe '::publish' do
    %w{with without}.each do |w|
      it "publishes synchronously (#{w} publisher confirms)" do
        use_publisher_confirms = w == 'with'
        sent = {'a' => 1}
        received = []
        test_with_mercury(wait_for_publisher_confirms: use_publisher_confirms) do |m|
          seql do
            and_then { m.start_listener(source, received.method(:push)) }
            and_lift { Mercury::Sync.publish(source, sent, headers: headers) }
            and_then { wait_until { received.any? } }
            and_lift do
              expect(received.size).to eql 1
              expect(received[0].content).to eql sent
              expect(received[0].headers).to eql headers
            end
          end
        end
      end
    end
  end

  # the block must return a Cps
  def test_with_mercury(**kws, &block)
    sources = [source]
    queues = [queue]
    test_with_mercury_cps(sources, queues, **kws, &block)
  end
end
