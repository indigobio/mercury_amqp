require 'mercury/mercury'
require 'bunny'

class Mercury
  class Sync
    class << self
      def publish(source_name, msg, tag: '', amqp_opts: {})
        conn = Bunny.new(amqp_opts)
        conn.start
        ch = conn.create_channel
        ch.confirm_select # see http://rubybunny.info/articles/extensions.html and Mercury#enable_publisher_confirms
        ex = ch.topic(source_name, Mercury.source_opts)
        ex.publish(WireSerializer.new.write(msg), **Mercury.publish_opts(tag, {}))
        ch.wait_for_confirms or raise 'failed to confirm publication'
      ensure
        conn.close
      end
    end
  end
end
