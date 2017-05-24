require 'oj'

class Mercury
  class WireSerializer
    # TODO: DRY with hyperion once we know more

    def write(struct_or_hash)
      write_json(struct_or_hash)
    end

    def read(bytes)
      read_json(bytes)
    end

    private

    def write_json(obj)
      if obj.is_a?(String)
        obj
      else
        Oj.dump(hashify(obj), oj_options)
      end
    end

    def read_json(bytes)
      begin
        Oj.compat_load(bytes, oj_options)
      rescue Oj::ParseError => e
        bytes
      end
    end

    def oj_options
      {
        mode: :rails,
        time_format: :xmlschema,  # xmlschema == iso8601
        second_precision: 3,
        bigdecimal_load: :float
      }
    end

    def hashify(x)
      case x
      when Hash
        x
      when Struct
        x.to_h
      else
        raise "Could not convert to hash: #{x.inspect}"
      end
    end

  end
end
