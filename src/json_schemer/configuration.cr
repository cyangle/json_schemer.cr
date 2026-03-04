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
    # Access mode ("read" or "write") for readOnly/writeOnly validation.
    property access_mode : String?

    # Base URI for resolving relative references.
    # Default is a generated URI `json-schemer://schema`.
    property base_uri : URI

    # Custom content encoding validators.
    property content_encodings : Hash(String, Content::ContentEncodingValidator)

    # Custom content media type validators.
    property content_media_types : Hash(String, Content::ContentMediaTypeValidator)

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

    # Whether to insert default values (mutates the instance).
    property insert_property_defaults : Bool

    # Custom keywords.
    property custom_keywords : Hash(String, Proc(JSON::Any, JSON::Any, String, Keyword, Bool | Array(String)))

    # Maximum recursion depth during validation to prevent stack overflows (Security limit).
    # Default is 50.
    property max_depth : Int32 = 50

    # The meta-schema used for validating the schema itself.
    # Default is `https://json-schema.org/draft/2020-12/schema`.
    property meta_schema : String | Schema

    # Output format ("flag", "basic", "classic").
    # Default is "classic".
    property output_format : String

    # Resolver for property defaults.
    property property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)?

    # Resolver for external $refs.
    # Can be a Proc or a String ("net/http").
    property ref_resolver : Proc(URI, JSONHash?) | String

    # Optional custom filter for regular expression patterns.
    # Takes the pattern string and returns true if it is allowed.
    property regexp_filter : Proc(String, Bool)?

    # Resolver for regexp patterns ("ruby" or "ecma").
    # Default is "ruby".
    property regexp_resolver : Proc(String, Regex?) | String

    # Configuration for standard vocabularies.
    property vocabulary : Hash(String, Bool)?

    # Initializes a new Configuration instance with default values.
    def initialize(
      @access_mode : String? = nil,
      @base_uri : URI = URI.parse("json-schemer://schema"),
      @content_encodings : Hash(String, Content::ContentEncodingValidator) = {} of String => Content::ContentEncodingValidator,
      @content_media_types : Hash(String, Content::ContentMediaTypeValidator) = {} of String => Content::ContentMediaTypeValidator,
      @format : Bool = true,
      @formats : Hash(String, Format::FormatValidator) = {} of String => Format::FormatValidator,
      @insert_property_defaults : Bool = false,
      @custom_keywords : Hash(String, Proc(JSON::Any, JSON::Any, String, Keyword, Bool | Array(String))) = {} of String => Proc(JSON::Any, JSON::Any, String, Keyword, Bool | Array(String)),
      @max_depth : Int32 = 50,
      @meta_schema : String | Schema = "https://json-schema.org/draft/2020-12/schema",
      @output_format : String = "classic",
      @property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)? = nil,
      @ref_resolver : Proc(URI, JSONHash?) | String = DEFAULT_REF_RESOLVER,
      @regexp_filter : Proc(String, Bool)? = nil,
      @regexp_resolver : Proc(String, Regex?) | String = "ruby",
      @vocabulary : Hash(String, Bool)? = nil,
    )
      valid_output_formats = {"flag", "basic", "classic", "detailed", "verbose"}
      unless valid_output_formats.includes?(@output_format)
        raise ArgumentError.new("Invalid output_format: #{@output_format.inspect}. Valid values: #{valid_output_formats.join(", ")}")
      end

      if am = @access_mode
        valid_access_modes = {"read", "write"}
        unless valid_access_modes.includes?(am)
          raise ArgumentError.new("Invalid access_mode: #{am.inspect}. Valid values: #{valid_access_modes.join(", ")}")
        end
      end

      if @max_depth <= 0
        raise ArgumentError.new("max_depth must be > 0, got: #{@max_depth}")
      end
    end
  end
end
