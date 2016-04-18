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
                 parallelism: 1,
                 on_error: nil,
                 &k)
    @on_error = on_error
    AMQP.connect(host: host, port: port, vhost: vhost, username: username, password: password,
                 on_tcp_connection_failure: server_down_error_handler) do |amqp|
      @amqp = amqp
      @confirm_handlers = {}
      @channel = AMQP::Channel.new(amqp, prefetch: parallelism) do
        install_channel_error_handler
        install_lost_connection_error_handler
        enable_publisher_confirms do
          k.call(self)
        end
      end
    end
  end
  private_class_method :new

  def publish(source_name, msg, tag: '', headers: {}, &k)
    # The amqp gem caches exchange objects, so it's fine to
    # redeclare the exchange every time we publish.
    with_source(source_name) do |exchange|
      payload = write(msg)
      pub_opts = Mercury.publish_opts(tag, headers)
      tag = expect_publisher_confirm(k)
      exchange.publish(payload, **pub_opts)
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

  # In AMQP, queue consumers ack requests after handling them. Unacked messages
  # are automatically returned to the queue, guaranteeing they are eventually handled.
  # Services often ack one request while publishing related messages. Ideally, these
  # operations would be transactional. If the ack succeeds but the publish does not,
  # the line of processing is abandoned, resulting in processing getting "stuck".
  # The best we can do in AMQP is to use "publisher confirms" to confirm that the publish
  # succeeded before acking the originating request. Since the ack can still fail in this
  # scenario, the system should employ idempotent design, which makes request redelivery
  # harmless.
  #
  # see https://www.rabbitmq.com/confirms.html
  # see http://rubyamqp.info/articles/durability/
  def enable_publisher_confirms(&k)

    @channel.confirm_select do
      @last_published_delivery_tag = 0
      @channel.on_ack do |basic_ack|
        tag = basic_ack.delivery_tag
        if @confirm_handlers.keys.exclude?(tag)
          raise "Got an unexpected publish confirmation ACK for delivery-tag: #{tag}. Was expecting one of: #{@confirm_handlers.keys.inspect}"
        end
        dispatch_publisher_confirm(basic_ack)
      end
      @channel.on_nack do |basic_nack|
        raise "Delivery failed for message with delivery-tag: #{basic_nack.delivery_tag}"
      end
      k.call
    end
  end

  def expect_publisher_confirm(k)
    expected_delivery_tag = (@last_published_delivery_tag += 1)
    @confirm_handlers[expected_delivery_tag] = k
    expected_delivery_tag
  end

  def dispatch_publisher_confirm(basic_ack)
    confirmed_tags =
      if basic_ack.multiple
        @confirm_handlers.keys.select { |tag| tag <= basic_ack.delivery_tag }.sort # sort just to be deterministic
      else
        [basic_ack.delivery_tag]
      end
    confirmed_tags.each do |tag|
      @confirm_handlers.delete(tag).call
    end
  end

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
          handle_channel_error(ch, info)
        end
      end
      check.call(ch) do |result|
        ch.close do
          k.call(result)
        end
      end
    end
  end

  def server_down_error_handler
    make_error_handler('Failed to establish connection to AMQP server. Exiting.')
  end

  def install_lost_connection_error_handler
    @amqp.on_tcp_connection_loss(&make_error_handler('Lost connection to AMQP server. Exiting.'))
  end

  def install_channel_error_handler
    @channel.on_error(&method(:handle_channel_error))
  end

  def handle_channel_error(_ch, info)
    @amqp.close do
      make_error_handler("An error occurred: #{info.reply_code} - #{info.reply_text}").call
    end
  end

  def make_error_handler(msg)
    proc do
      Logatron.error(msg)
      if @on_error.respond_to?(:call)
        @on_error.call(msg)
      else
        raise msg
      end
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
