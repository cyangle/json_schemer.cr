module JsonSchemer
  # Configuration class for schema validation options.
  #
  # This class holds all configuration options for schema validation, such as
  # custom formats, ref resolvers, and output formats.
  #
  # You can modify the global configuration using `JsonSchemer.configure`:
  #
  # ```
  # JsonSchemer.configure do |config|
  #   config.output_format = "basic"
  #   config.format = true
  #   config.ref_resolver = "net/http"
  # end
  # ```
  #
  # Or pass options when creating a schema:
  #
  # ```
  # schema = JsonSchemer.schema(
  #   %q({"format": "email"}),
  #   format: true,
  #   output_format: "classic"
  # )
  # ```
  class Configuration
    # Base URI for resolving relative references.
    # Default is a generated URI `json-schemer://schema`.
    property base_uri : URI

    # The meta-schema used for validating the schema itself.
    # Default is `https://json-schema.org/draft/2020-12/schema`.
    property meta_schema : String | Schema

    # Configuration for standard vocabularies.
    property vocabulary : Hash(String, Bool)?

    # Enables format validation assertions (default: true).
    # Note: The JSON Schema spec makes format annotation-only by default, but this option
    # allows enabling assertion behavior.
    property format : Bool

    # Custom format validators.
    # Map of format name to validator proc.
    #
    # ```
    # config.formats["even"] = ->(value : JSON::Any, format : String) {
    #   value.as_i64? && value.as_i64.even?
    # }
    # ```
    property formats : Hash(String, Format::FormatValidator)

    # Custom content encoding validators.
    property content_encodings : Hash(String, Content::ContentEncodingValidator)

    # Custom content media type validators.
    property content_media_types : Hash(String, Content::ContentMediaTypeValidator)

    # Custom keywords.
    property keywords : Hash(String, Proc(JSON::Any, JSON::Any, String, Bool | Array(String)))

    # Hooks to run before validating a property.
    property before_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil))

    # Hooks to run after validating a property.
    property after_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil))

    # Whether to insert default values (not fully implemented).
    property insert_property_defaults : Bool | Symbol

    # Resolver for property defaults.
    property property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)?

    # Resolver for external $refs.
    # Can be a Proc or a String ("net/http").
    property ref_resolver : Proc(URI, JSONHash?) | String

    # Resolver for regexp patterns ("ruby" or "ecma").
    # Default is "ruby".
    property regexp_resolver : Proc(String, Regex?) | String

    # Output format ("flag", "basic", "classic").
    # Default is "classic".
    property output_format : String

    # Whether to resolve enumerators.
    property resolve_enumerators : Bool

    # Access mode ("read" or "write") for readOnly/writeOnly validation.
    property access_mode : String?

    # Initializes a new Configuration instance with default values.
    def initialize(
      @base_uri : URI = URI.parse("json-schemer://schema"),
      @meta_schema : String | Schema = "https://json-schema.org/draft/2020-12/schema",
      @vocabulary : Hash(String, Bool)? = nil,
      @format : Bool = true,
      @formats : Hash(String, Format::FormatValidator) = {} of String => Format::FormatValidator,
      @content_encodings : Hash(String, Content::ContentEncodingValidator) = {} of String => Content::ContentEncodingValidator,
      @content_media_types : Hash(String, Content::ContentMediaTypeValidator) = {} of String => Content::ContentMediaTypeValidator,
      @keywords : Hash(String, Proc(JSON::Any, JSON::Any, String, Bool | Array(String))) = {} of String => Proc(JSON::Any, JSON::Any, String, Bool | Array(String)),
      @before_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil)) = [] of Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil),
      @after_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil)) = [] of Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil),
      @insert_property_defaults : Bool | Symbol = false,
      @property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)? = nil,
      @ref_resolver : Proc(URI, JSONHash?) | String = DEFAULT_REF_RESOLVER,
      @regexp_resolver : Proc(String, Regex?) | String = "ruby",
      @output_format : String = "classic",
      @resolve_enumerators : Bool = false,
      @access_mode : String? = nil,
    )
    end

    def dup_with(**options) : Configuration
      Configuration.new(
        base_uri: options[:base_uri]? || @base_uri,
        meta_schema: options[:meta_schema]? || @meta_schema,
        vocabulary: options[:vocabulary]? || @vocabulary,
        format: options.has_key?(:format) ? options[:format].as(Bool) : @format,
        formats: options[:formats]? || @formats,
        content_encodings: options[:content_encodings]? || @content_encodings,
        content_media_types: options[:content_media_types]? || @content_media_types,
        keywords: options[:keywords]? || @keywords,
        before_property_validation: options[:before_property_validation]? || @before_property_validation,
        after_property_validation: options[:after_property_validation]? || @after_property_validation,
        insert_property_defaults: options.has_key?(:insert_property_defaults) ? options[:insert_property_defaults].as(Bool | Symbol) : @insert_property_defaults,
        property_default_resolver: options[:property_default_resolver]? || @property_default_resolver,
        ref_resolver: options[:ref_resolver]? || @ref_resolver,
        regexp_resolver: options[:regexp_resolver]? || @regexp_resolver,
        output_format: options[:output_format]? || @output_format,
        resolve_enumerators: options.has_key?(:resolve_enumerators) ? options[:resolve_enumerators].as(Bool) : @resolve_enumerators,
        access_mode: options[:access_mode]? || @access_mode
      )
    end
  end
end
