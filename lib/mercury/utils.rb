class Mercury
  class Utils
    def self.unsplat(args)
      if args.size == 1 && args.first.is_a?(Array)
        args.first
      else
        args
      end
    end
  end
end
