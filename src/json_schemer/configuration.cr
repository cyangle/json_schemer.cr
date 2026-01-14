module JsonSchemer
  # Configuration class for schema validation options
  class Configuration
    property base_uri : URI
    property meta_schema : String | Schema
    property vocabulary : Hash(String, Bool)?
    property format : Bool
    property formats : Hash(String, Format::FormatValidator)
    property content_encodings : Hash(String, Content::ContentEncodingValidator)
    property content_media_types : Hash(String, Content::ContentMediaTypeValidator)
    property keywords : Hash(String, Proc(JSON::Any, JSON::Any, String, Bool | Array(String)))
    property before_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil))
    property after_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil))
    property insert_property_defaults : Bool | Symbol
    property property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)?
    property ref_resolver : Proc(URI, JSONHash?) | String
    property regexp_resolver : Proc(String, Regex?) | String
    property output_format : String
    property resolve_enumerators : Bool
    property access_mode : String?

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
