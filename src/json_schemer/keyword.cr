module JsonSchemer
  # Base class for all JSON Schema keywords
  abstract class Keyword
    include Output

    @lock = Mutex.new(protection: :reentrant)
    @absolute_keyword_location : String?
    @schema_pointer : String?

    getter value : JSON::Any
    getter parent : Schema | Keyword
    getter root : Schema
    getter keyword : String
    getter location : Location::Node
    getter parsed : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil

    getter schema : Schema

    def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
      @root = parent.root
      @schema = schema || (parent.is_a?(Schema) ? parent : parent.schema)
      @location = @schema.location.join(@keyword)
      parse_result = parse
      # After parse, ensure instance variables are set if they were not nullable
      @parsed = parse_result
    end

    # Exclusive keyword? (e.g. $ref in older drafts)
    def self.exclusive? : Bool
      false
    end

    # Override in subclasses to perform validation
    def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
      nil
    end

    # Absolute keyword location for output
    def absolute_keyword_location : String
      @absolute_keyword_location || @lock.synchronize do
        @absolute_keyword_location ||= "#{parent.absolute_keyword_location}/#{fragment_encode(escaped_keyword)}"
      end
    end

    # Schema pointer for output
    def schema_pointer : String
      @schema_pointer || @lock.synchronize do
        @schema_pointer ||= "#{parent.schema_pointer}/#{escaped_keyword}"
      end
    end

    # Error key for i18n
    def error_key : String
      keyword
    end

    # Fetch nested item
    def fetch(key : String) : Keyword | Schema
      p = parsed
      case p
      when Hash
        p[key].as(Schema | Keyword)
      when Array
        p[key.to_i].as(Schema)
      else
        raise KeyError.new("Key not found: #{key}")
      end
    end

    # Get parsed schema if value is a schema
    def parsed_schema : Schema?
      parsed.is_a?(Schema) ? parsed.as(Schema) : nil
    end

    # Error message generator
    def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
      "value at #{formatted_instance_location} does not match schema"
    end

    # False schema error (for keywords like additionalProperties: false)
    def false_schema_error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
      error(formatted_instance_location, details)
    end

    # x-error support
    def x_error : String?
      schema.parsed["x-error"]?.try do |xerr|
        if xerr.is_a?(Keyword)
          xerr.as(Draft202012::Vocab::Core::XError).message(error_key)
        end
      end
    end

    protected def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
      value
    end

    # Helper: Parse value as an array of subschemas
    # Used by: AllOf, AnyOf, OneOf, PrefixItems
    protected def parse_subschema_array : Array(Schema)
      unless value.raw.is_a?(Array)
        raise InvalidSchema.new("Value for keyword '#{keyword}' must be an array")
      end
      value.as_a.map_with_index do |subschema_value, index|
        subschema(subschema_value, index.to_s)
      end
    end

    # Helper: Parse value as a hash of subschemas
    # Used by: Properties, PatternProperties, DependentSchemas, $defs
    protected def parse_subschema_hash : Hash(String, Schema)
      unless value.raw.is_a?(Hash)
        raise InvalidSchema.new("Value for keyword '#{keyword}' must be an object")
      end
      result = {} of String => Schema
      value.as_h.each do |key, subschema_value|
        result[key] = subschema(subschema_value, key)
      end
      result
    end

    # Create a subschema from a value
    protected def subschema(value : JSON::Any, kw : String? = nil) : Schema
      Schema.new(
        value,
        self,
        root,
        kw,
        configuration: schema.configuration,
        base_uri: schema.base_uri,
        meta_schema: schema.meta_schema,
        ref_resolver: schema.ref_resolver,
        regexp_resolver: schema.regexp_resolver
      )
    end

    # Cache warmup hook
    def after_schema_initialize : Nil
    end

    protected def resolve_uri_reference(base : URI, ref_str : String) : URI
      ref = URI.parse(ref_str)
      # Handle fragment-only refs for opaque URIs (like urn:)
      # Crystal's URI.resolve doesn't work correctly for opaque URIs
      if ref.scheme.nil? && ref.path.empty? && ref.fragment
        result = base.dup
        result.fragment = ref.fragment
        result
      else
        base.resolve(ref)
      end
    end
  end
end
