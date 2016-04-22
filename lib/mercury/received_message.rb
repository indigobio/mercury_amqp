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
      @is_ackable or raise 'This message is not ackable'
      disallow_double_actions
      @action_taken = :ack
      metadata.ack
    end

    def reject
      @is_ackable or raise 'This message is not rejectable'
      disallow_double_actions
      @action_taken = :reject
      metadata.reject(requeue: false)
    end

    def nack
      @is_ackable or raise 'This message is not nackable'
      disallow_double_actions
      @action_taken = :nack
      metadata.reject(requeue: true)
    end

    private

    def disallow_double_actions
      if @action_taken
        raise "This message was already #{@action_taken}ed"
      end
    end
  end
end
