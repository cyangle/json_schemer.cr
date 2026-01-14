module JsonSchemer
  # Output module for result formatting
  module Output
    FRAGMENT_ENCODE_REGEX = /[^\w?\/:@\-.~!$&'()*+,;=]/

    # Create a result
    def result(
      instance : JSON::Any,
      instance_location : Location::Node,
      keyword_location : Location::Node,
      valid : Bool,
      nested : Array(Result)? = nil,
      type : String? = nil,
      result_annotation : JSON::Any? = nil,
      details : Hash(String, JSON::Any)? = nil,
      ignore_nested : Bool = false,
    ) : Result
      Result.new(
        source: self,
        instance: instance,
        instance_location: instance_location,
        keyword_location: keyword_location,
        valid: valid,
        nested: nested,
        type: type,
        result_annotation: result_annotation,
        details: details,
        ignore_nested: ignore_nested,
        nested_key: valid ? "annotations" : "errors"
      )
    end

    # Escape keyword for JSON pointer
    def escaped_keyword : String
      @escaped_keyword ||= Location.escape_json_pointer_token(keyword)
    end

    # Join location with keyword
    def join_location(location : Location::Node, kw : String) : Location::Node
      Location.join(location, kw)
    end

    # Fragment encode a location
    def fragment_encode(location : String) : String
      Format.percent_encode(location, FRAGMENT_ENCODE_REGEX)
    end

    # Deep stringify keys
    def deep_stringify_keys(obj : JSON::Any) : JSON::Any
      case obj.raw
      when Hash
        result = {} of String => JSON::Any
        obj.as_h.each do |key, value|
          result[key.to_s] = deep_stringify_keys(value)
        end
        JSON::Any.new(result)
      when Array
        JSON::Any.new(obj.as_a.map { |item| deep_stringify_keys(item) })
      else
        obj
      end
    end

    # Abstract methods that implementers should provide
    abstract def keyword : String
    abstract def schema : Schema
    abstract def value : JSON::Any
    abstract def absolute_keyword_location : String
  end
end
