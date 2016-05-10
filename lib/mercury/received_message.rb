class Mercury
  class ReceivedMessage
    attr_reader :content, :metadata, :action_taken, :work_queue_name

    def initialize(content, metadata, work_queue_name: nil)
      @content = content
      @metadata = metadata
      @work_queue_name = work_queue_name
    end

    def tag
      headers[Mercury::ORIGINAL_TAG_HEADER] || metadata.routing_key
    end

    def headers
      (metadata.headers || {}).dup
    end

    def republish_count
      (metadata.headers[Mercury::REPUBLISH_COUNT_HEADER] || 0).to_i
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

    def is_ackable
      !@work_queue_name.nil?
    end

    def performing_action(action)
      is_ackable || raise("This message is not #{action}able")
      raise "This message was already #{@action_taken}ed" if @action_taken
      @action_taken = action
    end
  end
end
