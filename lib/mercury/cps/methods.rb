class Mercury
  class Cps
    module Methods
      def lift(&block)
        Cps.lift(&block)
      end

      def seq(&block)
        Cps.seq(&block)
      end

      def seql(&block)
        Cps.seql(&block)
      end

      def seqp(&block)
        Cps.seqp(&block)
      end

      def cps(&block)
        Cps.new(&block)
      end
    end
  end
end
