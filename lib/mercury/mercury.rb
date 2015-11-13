require 'amqp'
require 'securerandom'
require 'mercury/wire_serializer'
require 'mercury/received_message'
require 'logatron/logatron'

class Mercury
  attr_reader :amqp, :channel, :logger

  def self.open(logger: Logatron, **kws, &k)
    @logger = logger
    new(**kws, &k)
    nil
  end

  def close(&k)
    @amqp.close do
      k.call
    end
  end

  def initialize(host: 'localhost',
                 port: 5672,
                 vhost: '/',
                 username: 'guest',
                 password: 'guest',
                 &k)
    AMQP.connect(host: host, port: port, vhost: vhost, username: username, password: password) do |amqp|
      @amqp = amqp
      @channel = AMQP::Channel.new(amqp, prefetch: 1) do
        @channel.confirm_select
        install_default_error_handler
        k.call(self)
      end
    end
  end
  private_class_method :new

  def publish(source_name, msg, tag: '', headers: {}, &k)
    # The amqp gem caches exchange objects, so it's fine to
    # redeclare the exchange every time we publish.
    # TODO: wait for publish confirmations (@channel.on_ack)
    with_source(source_name) do |exchange|
      exchange.publish(write(msg), **Mercury.publish_opts(tag, headers)) do
        k.call
      end
    end
  end

  def self.publish_opts(tag, headers)
    { routing_key: tag, persistent: true, headers: Logatron.http_headers.merge(headers) }
  end

  def start_listener(source_name, handler, tag_filter: '#', &k)
    with_source(source_name) do |exchange|
      with_listener_queue(exchange, tag_filter) do |queue|
        queue.subscribe(ack: false) do |metadata, payload|
          handler.call(make_received_message(payload, metadata, false))
        end
        k.call
      end
    end
  end

  def start_worker(worker_group, source_name, handler, tag_filter: '#', &k)
    with_source(source_name) do |exchange|
      with_work_queue(worker_group, exchange, tag_filter) do |queue|
        queue.subscribe(ack: true) do |metadata, payload|
          handler.call(make_received_message(payload, metadata, true))
        end
        k.call
      end
    end
  end

  def delete_source(source_name, &k)
    with_source(source_name) do |exchange|
      exchange.delete do
        k.call
      end
    end
  end

  def delete_work_queue(worker_group, &k)
    @channel.queue(worker_group, work_queue_opts) do |queue|
      queue.delete do
        k.call
      end
    end
  end

  def source_exists?(source_name, &k)
    existence_check(k) do |ch, &ret|
      with_source_no_cache(ch, source_name, passive: true) do
        ret.call(true)
      end
    end
  end

  def queue_exists?(queue_name, &k)
    existence_check(k) do |ch, &ret|
      ch.queue(queue_name, passive: true) do
        ret.call(true)
      end
    end
  end

  private

  def make_received_message(payload, metadata, is_ackable)
    msg = ReceivedMessage.new(read(payload), metadata, is_ackable: is_ackable)
    Logatron.msg_id = msg.headers['X-Ascent-Log-Id']
    msg
  end

  def existence_check(k, &check)
    AMQP::Channel.new(@amqp) do |ch|
      ch.on_error do |_, info|
        if info.reply_code == 404
          # our request failed because it does not exist
          k.call(false)
        else
          # failed for unknown reason
          default_error_handler(ch, info)
        end
      end
      check.call(ch) do |result|
        ch.close do
          k.call(result)
        end
      end
    end
  end

  def install_default_error_handler
    @channel.on_error(&method(:default_error_handler))
  end

  def default_error_handler(_ch, info)
    @amqp.close do
      raise "An error occurred: #{info.reply_code} - #{info.reply_text}"
    end
  end

  def write(msg)
    WireSerializer.new.write(msg)
  end

  def read(bytes)
    WireSerializer.new.read(bytes)
  end

  def with_source(source_name, &k)
    with_source_no_cache(@channel, source_name, Mercury.source_opts) do |exchange|
      k.call(exchange)
    end
  end

  def with_source_no_cache(channel, source_name, opts, &k)
    channel.topic(source_name, opts) do |*args|
      k.call(*args)
    end
  end

  def with_work_queue(worker_group, source_exchange, tag_filter, &k)
    bind_queue(source_exchange, worker_group, tag_filter, work_queue_opts, &k)
  end

  def self.source_opts
    { durable: true, auto_delete: false }
  end

  def work_queue_opts
    { durable: true, auto_delete: false }
  end

  def with_listener_queue(source_exchange, tag_filter, &k)
    bind_queue(source_exchange, '', tag_filter, exclusive: true, auto_delete: true, durable: false, &k)
  end

  def bind_queue(exchange, queue_name, tag_filter, opts, &k)
    queue = @channel.queue(queue_name, opts)
    queue.bind(exchange, routing_key: tag_filter) do
      k.call(queue)
    end
  end

end
