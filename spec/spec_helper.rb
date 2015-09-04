require 'rspec'
require 'mercury/test_utils'
require 'mercury/fake'
include Mercury::TestUtils

# the block must return a Cps
def test_with_mercury_cps(sources, queues, &block)
  em do
    seql do
      let(:m)  { Mercury::Monadic.open }
      and_then { delete_sources_and_queues_cps(sources, queues) }
      and_then { block.call(m) }
      and_then { delete_sources_and_queues_cps(sources, queues) }
      and_then { m.close }
      and_lift { done }
    end.run
  end
end

module MercuryFakeSpec
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # runs a test once with real mercury and once with Mercury::Fake
    def itt(name, &block)
      it(name, &block)
      context 'with Mercury::Fake' do
        before :each do
          allow(Mercury).to receive(:open) do |&k|
            EM.next_tick { k.call(Mercury::Fake.new) }
          end
        end
        it(name, &block)
      end
    end
  end
end
