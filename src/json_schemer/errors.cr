module JsonSchemer
  # Base error class
  class Error < Exception
  end

  # Unsupported OpenAPI version
  class UnsupportedOpenAPIVersion < Error
  end

  # Unknown $ref
  class UnknownRef < Error
  end

  # Unknown format
  class UnknownFormat < Error
  end

  # Unknown vocabulary
  class UnknownVocabulary < Error
  end

  # Unknown content encoding
  class UnknownContentEncoding < Error
  end

  # Unknown content media type
  class UnknownContentMediaType < Error
  end

  # Unknown output format
  class UnknownOutputFormat < Error
  end

  # Invalid ref resolution
  class InvalidRefResolution < Error
  end

  # Invalid ref pointer
  class InvalidRefPointer < Error
  end

  # Invalid regexp resolution
  class InvalidRegexpResolution < Error
  end

  # Invalid file URI
  class InvalidFileURI < Error
  end

  # Invalid ECMA regexp
  class InvalidEcmaRegexp < Error
  end

  # Pretty error formatting helper
  module Errors
    def self.pretty(error : Hash(String, JSON::Any)) : String
      data_pointer = error["data_pointer"]?.try(&.as_s) || ""
      type = error["type"]?.try(&.as_s) || ""
      schema_raw = error["schema"]?

      location = data_pointer.empty? ? "root" : "property '#{data_pointer}'"

      case type
      when "required"
        keys = error.dig?("details", "missing_keys").try do |arr|
          arr.as_a.map(&.as_s).join(", ")
        end || ""
        "#{location} is missing required keys: #{keys}"
      when "null", "string", "boolean", "integer", "number", "array", "object"
        "#{location} is not of type: #{type}"
      when "pattern"
        pattern = schema_raw.try do |s|
          s.as_h?.try(&.["pattern"]?.try(&.as_s))
        end || ""
        "#{location} does not match pattern: #{pattern}"
      when "format"
        format = schema_raw.try do |s|
          s.as_h?.try(&.["format"]?.try(&.as_s))
        end || ""
        "#{location} does not match format: #{format}"
      when "const"
        const_val = schema_raw.try do |s|
          s.as_h?.try(&.["const"]?)
        end
        "#{location} is not: #{const_val.inspect}"
      when "enum"
        enum_val = schema_raw.try do |s|
          s.as_h?.try(&.["enum"]?)
        end
        "#{location} is not one of: #{enum_val}"
      else
        "#{location} is invalid: error_type=#{type}"
      end
    end
  end
end
