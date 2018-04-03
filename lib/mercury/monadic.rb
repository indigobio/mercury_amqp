require 'mercury'
require 'mercury/cps'

class Mercury
  class Monadic

    def self.open(**kws)
      Cps.new do |&k|
        Mercury.open(**kws) do |m|
          k.call(new(m))
        end
      end
    end

    def self.wrap(method_name)
      define_method(method_name) do |*args, **kws, &block|
        Cps.new do |&k|
          if @mercury.method(method_name).parameters.map(&:first).include?(:key)
            @mercury.send(method_name, *[*args, *block], **kws, &k)
          else
            @mercury.send(method_name, *[*args, *block], &k)
          end
        end
      end
    end

    wrap(:publish)
    wrap(:republish)
    wrap(:start_listener)
    wrap(:start_worker)
    wrap(:start_queue_worker)
    wrap(:delete_source)
    wrap(:delete_work_queue)
    wrap(:source_exists?)
    wrap(:queue_exists?)
    wrap(:close)

    private
    def initialize(mercury)
      @mercury = mercury
    end
  end
end
