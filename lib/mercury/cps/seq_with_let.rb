class Mercury
  class Cps
    # Syntactic sugar for and_then chains.
    def self.seql(&block)
      # EXPERIMENTAL
      # The trick here is to execute the block in a context where
      # 1. we can simulate local let-bound variables, and
      # 2. the block can access variables and methods available
      #    outside the call to seql.
      #
      # To achieve this, we instance_exec the block in a SeqWithLet
      # object, which provides the let bound variables (as methods)
      # and uses method_missing to proxy other methods to the parent
      # binding.
      #
      # Note: parent instance variables are not available inside the block.
      # Note: keyword arguments are not proxied to methods called in the parent binding
      context = SeqWithLet.new(block.binding)
      context.instance_exec(&block)
      context.__chain
    end

    class SeqWithLet

      def and_then(&block)
        @__chain = __chain.and_then(&block)
      end

      def and_lift(&block)
        @__chain = __chain.and_lift(&block)
      end

      def let(name, &block)
        and_then(&block)
        and_then do |value|
          __values[name] = value
          Cps.lift{value}
        end
      end

      def initialize(parent_binding)
        @__parent_binding = parent_binding
      end

      def __chain
        @__chain ||= Cps.identity
      end

      def method_missing(name, *args, &block)
        __values.fetch(name) { __parent_call(name.to_s, *args, &block) }
      end

      def __parent_call(name, *args, &block)
        @__parent_caller ||= @__parent_binding.eval <<-EOD
      proc do |name, *args, &block|
        send(name, *args, &block)
      end
        EOD
        @__parent_caller.call(name, *args, &block)
      end

      def __values
        @__values ||= {}
      end
    end
  end
end
