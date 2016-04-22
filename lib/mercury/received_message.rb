class Mercury
  class ReceivedMessage
    attr_reader :content, :metadata, :action_taken

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
      performing_action(:ack)
      metadata.ack
    end

    def reject
      performing_action(:reject)
      metadata.reject(requeue: false)
    end

    def nack
      performing_action(:nack)
      metadata.reject(requeue: true)
    end

    private

    def performing_action(action)
      @is_ackable or raise "This message is not #{action}able"
      if @action_taken
        raise "This message was already #{@action_taken}ed"
      end
      @action_taken = action
    end
  end
end
