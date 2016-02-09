class Mercury
  class Fake
    class Subscriber
      attr_reader :handler
      attr_accessor :handle_capacity

      def initialize(handler, handle_capacity)
        @handler = handler
        @handle_capacity = handle_capacity
      end
    end
  end
end
