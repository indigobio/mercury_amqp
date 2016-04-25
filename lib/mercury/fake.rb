require 'securerandom'
require 'delegate'
require 'mercury/received_message'
require 'mercury/fake/domain'
require 'mercury/fake/metadata'
require 'mercury/fake/queue'
require 'mercury/fake/queued_message'
require 'mercury/fake/subscriber'

# This class simulates Mercury without using the AMQP gem.
# It can be useful for unit testing code that uses Mercury.
# The domain concept allows different mercury instances to
# hit different virtual servers; this should rarely be needed.
# This class cannot simulate behavior of server disconnections,
# broken sockets, etc.
class Mercury
  class Fake
    def initialize(domain=:default, parallelism: 1)
      @domain = Fake.domains[domain]
      @parallelism = parallelism
    end

    def self.domains
      @domains ||= Hash.new { |h, k| h[k] = Domain.new }
    end

    def close(&k)
      @closed = true
      ret(k)
    end

    def publish(source_name, msg, tag: '', headers: {}, &k)
      assert_not_closed
      queues.values.select{|q| q.binds?(source_name, tag)}.each{|q| q.enqueue(roundtrip(msg), tag, headers)}
      ret(k)
    end

    def start_listener(source_name, handler, tag_filter: '#', &k)
      start_worker_or_listener(source_name, handler, tag_filter, &k)
    end

    def start_worker(worker_group, source_name, handler, tag_filter: '#', &k)
      start_worker_or_listener(source_name, handler, tag_filter, worker_group, &k)
    end

    def start_worker_or_listener(source_name, handler, tag_filter, worker_group=nil, &k)
      assert_not_closed
      q = ensure_queue(source_name, tag_filter, !!worker_group, worker_group)
      ret(k) # it's important we show the "start" operation finishing before delivery starts (in add_subscriber)
      q.add_subscriber(Subscriber.new(handler, @parallelism))
    end
    private :start_worker_or_listener

    def delete_source(source_name, &k)
      assert_not_closed
      queues.delete_if{|_k, v| v.source == source_name}
      ret(k)
    end

    def delete_work_queue(worker_group, &k)
      assert_not_closed
      queues.delete_if{|_k, v| v.worker == worker_group}
      ret(k)
    end

    def source_exists?(source, &k)
      built_in_sources = %w(direct topic fanout headers match rabbitmq.log rabbitmq.trace).map{|x| "amq.#{x}"}
      ret(k, (queues.values.map(&:source) + built_in_sources).include?(source))
    end

    def queue_exists?(worker, &k)
      ret(k, queues.values.map(&:worker).include?(worker))
    end

    private

    def queues
      @domain.queues
    end

    def ret(k, value=nil)
      EM.next_tick{k.call(value)} if k
    end

    def roundtrip(msg)
      ws = WireSerializer.new
      ws.read(ws.write(msg))
    end

    def ensure_queue(source, tag_filter, require_ack, worker=nil)
      worker ||= SecureRandom.uuid
      queues.fetch(unique_queue_name(source, tag_filter, worker)) do |k|
        queues[k] = Queue.new(source, tag_filter, worker, require_ack)
      end
    end

    def unique_queue_name(source, tag_filter, worker)
      [source, tag_filter, worker].join('^')
    end

    def assert_not_closed
      raise 'This mercury instance is defunct. Either it was purposely closed or an error occurred.' if @closed
    end
  end
end
