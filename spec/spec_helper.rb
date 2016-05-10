require 'rspec'
require 'mercury/test_utils'
require 'mercury/fake'
include Mercury::TestUtils

# the block must return a Cps
def test_with_mercury_cps(sources, queues, **kws)
  em do
    seql do
      let(:m)  { Mercury::Monadic.open(**kws) }
      and_then { delete_sources_and_queues_cps(sources, queues) }
      and_then { yield(m) }
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
      context 'without publisher confirms' do
        before :each do
          real_open = Mercury.method(:open)
          allow(Mercury).to receive(:open) do |**kws, &k|
            real_open.call(**kws.merge(wait_for_publisher_confirms: false), &k)
          end
        end
        it(name, &block)
      end
      context 'with Mercury::Fake' do
        before(:each) { Mercury::Fake.install(self) }
        it(name, &block)
      end
    end
  end
end
