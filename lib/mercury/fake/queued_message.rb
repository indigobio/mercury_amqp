require 'mercury/fake/metadata'
require 'mercury/received_message'

class Mercury
  class Fake
    class QueuedMessage
      attr_reader :received_msg, :headers
      attr_accessor :delivered, :subscriber

      def initialize(queue, msg, tag, headers, is_ackable)
        metadata = Metadata.new(tag, headers, proc{queue.ack_or_reject_message(self)}, proc{queue.nack(self)})
        @received_msg = ReceivedMessage.new(msg, metadata, is_ackable: is_ackable)
        @headers = headers
        @delivered = false
      end
    end
  end
end
