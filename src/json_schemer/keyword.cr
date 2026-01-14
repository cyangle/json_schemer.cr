module JsonSchemer
  # Base class for all JSON Schema keywords
  abstract class Keyword
    include Output

    getter value : JSON::Any
    getter parent : Schema | Keyword
    getter root : Schema
    getter keyword : String
    getter parsed : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil

    @schema : Schema
    @absolute_keyword_location : String?
    @schema_pointer : String?
    @escaped_keyword : String?

    def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
      @root = parent.root
      @schema = schema || (parent.is_a?(Schema) ? parent : parent.schema)
      @parsed = parse
    end

    def schema : Schema
      @schema
    end

    # Exclusive keyword? (e.g. $ref in older drafts)
    def self.exclusive? : Bool
      false
    end

    # Override in subclasses to perform validation
    def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
      nil
    end

    # Absolute keyword location for output
    def absolute_keyword_location : String
      @absolute_keyword_location ||= "#{parent.absolute_keyword_location}/#{fragment_encode(escaped_keyword)}"
    end

    # Schema pointer for output
    def schema_pointer : String
      @schema_pointer ||= "#{parent.schema_pointer}/#{escaped_keyword}"
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
      schema.parsed["x-error"]?.try do |xe|
        if xe.is_a?(Keyword)
          xe.as(Draft202012::Vocab::Core::XError).message(error_key)
        end
      end
    end

    protected def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
      value
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
  end
end
