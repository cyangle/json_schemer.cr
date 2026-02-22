module JsonSchemer
  # Base error class for all JsonSchemer errors.
  class Error < Exception
  end

  # Raised when an unsupported OpenAPI version is encountered.
  class UnsupportedOpenAPIVersion < Error
  end

  # Raised when a `$ref` cannot be resolved.
  class UnknownRef < Error
  end

  # Raised when an unknown format is encountered during validation.
  class UnknownFormat < Error
  end

  # Raised when an unknown vocabulary is encountered.
  class UnknownVocabulary < Error
  end

  # Raised when an unknown content encoding is encountered.
  class UnknownContentEncoding < Error
  end

  # Raised when an unknown content media type is encountered.
  class UnknownContentMediaType < Error
  end

  # Raised when an unknown output format is specified.
  class UnknownOutputFormat < Error
  end

  # Raised when a reference cannot be resolved.
  class InvalidRefResolution < Error
  end

  # Raised when a JSON pointer in a reference is invalid.
  class InvalidRefPointer < Error
  end

  # Raised when a regular expression cannot be resolved or compiled.
  class InvalidRegexpResolution < Error
  end

  # Raised when a file URI is invalid.
  class InvalidFileURI < Error
  end

  # Raised when an ECMA regular expression is invalid or incompatible.
  class InvalidEcmaRegexp < Error
  end

  # Raised when a schema keyword value has an invalid type.
  class InvalidSchema < Error
  end

  # Raised when the validation recursion depth exceeds the configured maximum.
  class MaximumDepthExceeded < Error
    def initialize(depth : Int32)
      super("Maximum validation depth of #{depth} exceeded. This usually indicates a deeply nested or malicious JSON instance.")
    end
  end

  # Raised when a regular expression match exceeds the backtracking limit (ReDoS protection).
  class RegexMatchLimitExceeded < Error
    def initialize(pattern : String)
      super("Regular expression match limit exceeded for pattern: #{pattern.inspect}. This indicates potential catastrophic backtracking (ReDoS).")
    end
  end

  # Raised when a schema contains a regular expression pattern that is disallowed.
  class RegexFilterViolation < Error
    def initialize(pattern : String)
      super("Regular expression pattern is disallowed by configuration: #{pattern.inspect}")
    end
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
        pattern = schema_raw.try do |schema|
          schema.as_h?.try(&.["pattern"]?.try(&.as_s))
        end || ""
        "#{location} does not match pattern: #{pattern}"
      when "format"
        format = schema_raw.try do |schema|
          schema.as_h?.try(&.["format"]?.try(&.as_s))
        end || ""
        "#{location} does not match format: #{format}"
      when "const"
        const_val = schema_raw.try do |schema|
          schema.as_h?.try(&.["const"]?)
        end
        "#{location} is not: #{const_val.inspect}"
      when "enum"
        enum_val = schema_raw.try do |schema|
          schema.as_h?.try(&.["enum"]?)
        end
        "#{location} is not one of: #{enum_val}"
      else
        "#{location} is invalid: error_type=#{type}"
      end
    end
  end
end
