class Mercury
  class Cps
    # Syntactic sugar for and_then chains.
    def self.seq(&block)
      s = Seq.new
      block.call(s.method(:chain))
      s.m
    end

    class Seq
      def m
        @m ||= Cps.identity # we need an initial Cps to chain onto
      end

      def chain(proc = nil, &block)
        @m = m.and_then(&(proc || block))
      end
    end
  end
end

class Method
  alias en call # to be called `th.en`
end
