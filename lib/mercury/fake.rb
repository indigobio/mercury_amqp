require 'securerandom'
require 'delegate'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/deep_dup'
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
    def self.install(rspec_context, domain=:default)
      rspec_context.instance_exec do
        allow(Mercury).to receive(:open) do |**kws, &k|
          EM.next_tick { k.call(Mercury::Fake.new(domain, **kws)) } # EM.next_tick is required to emulate the real Mercury.open
        end
      end
    end

    def initialize(domain=:default, **kws)
      @domain = Fake.domains[domain]
      @parallelism = kws.fetch(:parallelism, 1)
      ignored_keys = kws.keys - [:parallelism]
      if ignored_keys.any?
        $stderr.puts "Warning: Mercury::Fake::new is ignoring keyword arguments: #{ignored_keys.join(', ')}"
      end
    end

    def self.domains
      @domains ||= Hash.new { |h, k| h[k] = Domain.new }
    end

    def close(&k)
      @closed = true
      ret(k)
    end

    def publish(source_name, msg, tag: '', headers: {}, &k)
      guard_public(k)
      queues.values.select{|q| q.binds?(source_name, tag)}.each{|q| q.enqueue(roundtrip(msg), tag, headers.stringify_keys)}
      ret(k)
    end

    def republish(msg, &k)
      guard_public(k)
      msg.ack
      queue = queues.values.detect{|q| q.worker == msg.work_queue_name}
      queue.enqueue(roundtrip(msg.content), msg.tag, Mercury.increment_republish_count(msg))
      ret(k)
    end

    def start_listener(source_name, handler, tag_filter: nil, &k)
      start_worker_or_listener(source_name, handler, tag_filter, &k)
    end

    def start_worker(worker_group, source_name, handler, tag_filter: nil, &k)
      start_worker_or_listener(source_name, handler, tag_filter, worker_group, &k)
    end

    def start_worker_or_listener(source_name, handler, tag_filter, worker_group=nil, &k)
      guard_public(k)
      tag_filter ||= '#'
      q = ensure_queue(source_name, tag_filter, worker_group)
      ret(k) # it's important we show the "start" operation finishing before delivery starts (in add_subscriber)
      q.add_subscriber(Subscriber.new(handler, @parallelism))
    end
    private :start_worker_or_listener

    def delete_source(source_name, &k)
      guard_public(k)
      queues.delete_if{|_k, v| v.source == source_name}
      ret(k)
    end

    def delete_work_queue(worker_group, &k)
      guard_public(k)
      queues.delete_if{|_k, v| v.worker == worker_group}
      ret(k)
    end

    def source_exists?(source, &k)
      guard_public(k)
      built_in_sources = %w(direct topic fanout headers match rabbitmq.log rabbitmq.trace).map{|x| "amq.#{x}"}
      ret(k, (queues.values.map(&:source) + built_in_sources).include?(source))
    end

    def queue_exists?(worker, &k)
      guard_public(k)
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

    def ensure_queue(source, tag_filter, worker)
      require_ack = worker != nil
      worker ||= SecureRandom.uuid
      queues.fetch(unique_queue_name(source, tag_filter, worker)) do |k|
        queues[k] = Queue.new(source, tag_filter, worker, require_ack)
      end
    end

    def unique_queue_name(source, tag_filter, worker)
      [source, tag_filter, worker].join('^')
    end

    def guard_public(k, initializing: false)
      Mercury.guard_public(@closed, k, initializing: initializing)
    end
  end
end
