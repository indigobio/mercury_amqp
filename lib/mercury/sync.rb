require 'mercury/mercury'
require 'bunny'

class Mercury
  class Sync
    class << self
      def publish(source_name, msg, tag: '', headers: {}, amqp_opts: {}, wait_for_publisher_confirms: true)
        conn = Bunny.new(amqp_opts)
        conn.start
        ch = conn.create_channel

        ch.confirm_select if wait_for_publisher_confirms # see http://rubybunny.info/articles/extensions.html and Mercury#enable_publisher_confirms
        ex = ch.topic(source_name, Mercury.source_opts)
        ex.publish(WireSerializer.new.write(msg), **Mercury.publish_opts(tag, headers))
        if wait_for_publisher_confirms
          ch.wait_for_confirms or raise 'failed to confirm publication'
        end
      ensure
        conn&.close
      end
    end
  end
end
