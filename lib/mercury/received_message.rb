class Mercury
  class ReceivedMessage
    attr_reader :content, :metadata

    def initialize(content, metadata, is_ackable: false)
      @content = content
      @metadata = metadata
      @is_ackable = is_ackable
    end

    def tag
      metadata.routing_key
    end

    def headers
      metadata.headers || {}
    end

    def ack
      @is_ackable or raise 'This message is not ackable'
      metadata.ack
    end

    def reject
      @is_ackable or raise 'This message is not rejectable'
      metadata.reject(requeue: false)
    end

    def nack
      @is_ackable or raise 'This message is not nackable'
      metadata.reject(requeue: true)
    end
  end
end
