class Mercury
  class Fake
    class Metadata
      attr_reader :headers

      def initialize(tag, headers, dequeue, requeue)
        @tag = tag
        @dequeue = dequeue
        @requeue = requeue
        @headers = headers
      end

      def routing_key
        @tag
      end

      def ack
        @dequeue.call
      end

      def reject(opts)
        requeue = opts[:requeue]
        requeue ? @requeue.call : @dequeue.call
      end
    end
  end
end
