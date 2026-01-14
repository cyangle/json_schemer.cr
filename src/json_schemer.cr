require "json"
require "uri"
require "big"
require "socket"
require "http/client"
require "base64"

require "hana"
require "simpleidn"

require "./json_schemer/version"
require "./json_schemer/errors"
require "./json_schemer/location"
require "./json_schemer/resources"
require "./json_schemer/cached_resolver"
require "./json_schemer/ecma_regexp"
require "./json_schemer/format"
require "./json_schemer/content"
require "./json_schemer/output"
require "./json_schemer/result"
require "./json_schemer/configuration"
require "./json_schemer/keyword"
require "./json_schemer/draft202012/vocab/core"
require "./json_schemer/draft202012/vocab/validation"
require "./json_schemer/draft202012/vocab/applicator"
require "./json_schemer/draft202012/vocab/unevaluated"
require "./json_schemer/draft202012/vocab/format_annotation"
require "./json_schemer/draft202012/vocab/format_assertion"
require "./json_schemer/draft202012/vocab/content"
require "./json_schemer/draft202012/vocab/meta_data"
require "./json_schemer/draft202012/vocab"
require "./json_schemer/draft202012/meta"
require "./json_schemer/openapi31/vocab/base"
require "./json_schemer/openapi31/vocab"
require "./json_schemer/openapi31/meta"
require "./json_schemer/openapi31/document"
require "./json_schemer/schema"
require "./json_schemer/openapi"

module JsonSchemer
  CATCHALL = "*"

  # Type alias for JSON hash
  alias JSONHash = Hash(String, JSON::Any)

  # Vocabularies mapping
  VOCABULARIES = {} of String => Hash(String, Keyword.class)

  # Vocabulary order for sorting
  VOCABULARY_ORDER = {} of String => Int32

  WINDOWS_URI_PATH_REGEX = /\A\/[a-z]:/i

  # Default ref resolver that raises for unknown refs
  DEFAULT_REF_RESOLVER = ->(uri : URI) : JSONHash? {
    raise UnknownRef.new(uri.to_s)
  }

  # Net HTTP ref resolver
  NET_HTTP_REF_RESOLVER = ->(uri : URI) : JSONHash? {
    response = HTTP::Client.get(uri)
    JSONHash.from_json(response.body)
  }

  # File URI ref resolver
  FILE_URI_REF_RESOLVER = ->(uri : URI) : JSONHash? {
    raise InvalidFileURI.new("must use `file` scheme") unless uri.scheme == "file"
    raise InvalidFileURI.new("cannot have a host (use `file:///`)") if uri.host && !uri.host.not_nil!.empty?
    path = uri.path.not_nil!
    path = path[1..] if path.matches?(WINDOWS_URI_PATH_REGEX)
    JSONHash.from_json(File.read(URI.decode(path)))
  }

  # Ruby regexp resolver
  RUBY_REGEXP_RESOLVER = ->(pattern : String) : Regex? {
    Regex.new(pattern)
  }

  # ECMA regexp resolver
  ECMA_REGEXP_RESOLVER = ->(pattern : String) : Regex? {
    Regex.new(EcmaRegexp.crystal_equivalent(pattern))
  }

  # Module-level schema method
  def self.schema(
    schema : String | JSONHash | Path,
    base_uri : URI? = nil,
    meta_schema : Schema | String | Nil = nil,
    vocabulary : Hash(String, Bool)? = nil,
    format : Bool? = nil,
    formats : Hash(String, Format::FormatValidator)? = nil,
    content_encodings : Hash(String, Content::ContentEncodingValidator)? = nil,
    content_media_types : Hash(String, Content::ContentMediaTypeValidator)? = nil,
    keywords : Hash(String, Proc(JSON::Any, JSON::Any, String, Bool | Array(String)))? = nil,
    before_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil))? = nil,
    after_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil))? = nil,
    insert_property_defaults : Bool | Symbol = false,
    property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)? = nil,
    ref_resolver : Proc(URI, JSONHash?) | String | Nil = nil,
    regexp_resolver : Proc(String, Regex?) | String | Nil = nil,
    output_format : String? = nil,
    resolve_enumerators : Bool? = nil,
    access_mode : String? = nil,
  ) : Schema
    resolved_schema, resolved_base_uri, resolved_ref_resolver = resolve_schema(schema, base_uri, ref_resolver)
    Schema.new(
      resolved_schema,
      base_uri: resolved_base_uri,
      meta_schema: meta_schema,
      vocabulary: vocabulary,
      format: format,
      formats: formats,
      content_encodings: content_encodings,
      content_media_types: content_media_types,
      keywords_config: keywords,
      before_property_validation: before_property_validation,
      after_property_validation: after_property_validation,
      insert_property_defaults: insert_property_defaults,
      property_default_resolver: property_default_resolver,
      ref_resolver: resolved_ref_resolver,
      regexp_resolver: regexp_resolver,
      output_format: output_format,
      resolve_enumerators: resolve_enumerators,
      access_mode: access_mode
    )
  end

  # Validate if schema itself is valid
  def self.valid_schema?(
    schema : String | JSONHash | Path,
    base_uri : URI? = nil,
    meta_schema : Schema | String | Nil = nil,
    ref_resolver : Proc(URI, JSONHash?) | String | Nil = nil,
    regexp_resolver : Proc(String, Regex?) | String | Nil = nil,
  ) : Bool
    resolved_schema, resolved_base_uri, resolved_ref_resolver = resolve_schema(schema, base_uri, ref_resolver)
    meta = resolve_meta_schema(resolved_schema, meta_schema, resolved_base_uri, resolved_ref_resolver, regexp_resolver)
    meta.valid?(resolved_schema)
  end

  # Validate schema and return errors
  def self.validate_schema(
    schema : String | JSONHash | Path,
    base_uri : URI? = nil,
    meta_schema : Schema | String | Nil = nil,
    ref_resolver : Proc(URI, JSONHash?) | String | Nil = nil,
    regexp_resolver : Proc(String, Regex?) | String | Nil = nil,
    output_format : String = "classic",
  ) : Hash(String, JSON::Any)
    resolved_schema, resolved_base_uri, resolved_ref_resolver = resolve_schema(schema, base_uri, ref_resolver)
    meta = resolve_meta_schema(resolved_schema, meta_schema, resolved_base_uri, resolved_ref_resolver, regexp_resolver)
    meta.validate(resolved_schema, output_format: output_format)
  end

  # Get draft 2020-12 meta schema
  def self.draft202012 : Schema
    @@draft202012 ||= Schema.new(
      Draft202012::SCHEMA,
      base_uri: Draft202012::BASE_URI,
      formats: Draft202012::FORMATS,
      content_encodings: Draft202012::CONTENT_ENCODINGS,
      content_media_types: Draft202012::CONTENT_MEDIA_TYPES,
      ref_resolver: Draft202012::Meta::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # Get OpenAPI 3.1 schema
  def self.openapi31 : Schema
    @@openapi31 ||= Schema.new(
      OpenAPI31::SCHEMA,
      base_uri: OpenAPI31::BASE_URI,
      formats: OpenAPI31::FORMATS,
      ref_resolver: OpenAPI31::Meta::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # Get OpenAPI 3.1 document schema
  def self.openapi31_document : Schema
    @@openapi31_document ||= Schema.new(
      OpenAPI31::Document::SCHEMA_BASE,
      ref_resolver: OpenAPI31::Document::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # OpenAPI document handler
  def self.openapi(document : JSONHash, **options) : OpenAPI
    OpenAPI.new(document, **options)
  end

  # Global configuration
  def self.configuration : Configuration
    @@configuration ||= Configuration.new
  end

  def self.configure(&)
    yield configuration
  end

  private def self.resolve_schema(
    schema : String | JSONHash | Path,
    base_uri : URI?,
    ref_resolver : Proc(URI, JSONHash?) | String | Nil,
  ) : {JSONHash, URI?, Proc(URI, JSONHash?) | String | Nil}
    case schema
    when String
      {JSONHash.from_json(schema), base_uri, ref_resolver}
    when Path
      resolved_uri = URI.parse("file:#{URI.encode_path(schema.expand.to_s)}")
      if ref_resolver
        {FILE_URI_REF_RESOLVER.call(resolved_uri).not_nil!, base_uri || resolved_uri, ref_resolver}
      else
        cached = CachedRefResolver.new(&FILE_URI_REF_RESOLVER)
        {cached.call(resolved_uri).not_nil!, base_uri || resolved_uri, cached.to_proc}
      end
    else
      {schema, base_uri, ref_resolver}
    end
  end

  private def self.resolve_meta_schema(
    schema : JSONHash,
    meta_schema : Schema | String | Nil,
    base_uri : URI?,
    ref_resolver : Proc(URI, JSONHash?) | String | Nil,
    regexp_resolver : Proc(String, Regex?) | String | Nil,
  ) : Schema
    parseable_schema = JSONHash.new
    if schema_meta = schema["$schema"]?
      if schema_meta.as_s?
        parseable_schema["$schema"] = schema_meta
      end
    end
    s = self.schema(parseable_schema, base_uri: base_uri, meta_schema: meta_schema, ref_resolver: ref_resolver, regexp_resolver: regexp_resolver)
    ms = s.meta_schema
    case ms
    when Schema
      ms
    when String
      # Resolve string meta schema
      if call = META_SCHEMA_CALLABLES_BY_BASE_URI_STR[ms]?
        call.call
      else
        s.resolve_ref(URI.parse(ms))
      end
    else
      # Should not happen given defaults
      draft202012
    end
  end

  # Register vocabularies after all classes are defined
  def self.register_vocabularies
    VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/core"] = Draft202012::Vocab::CORE
    VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/applicator"] = Draft202012::Vocab::APPLICATOR
    VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/unevaluated"] = Draft202012::Vocab::UNEVALUATED
    VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"] = Draft202012::Vocab::VALIDATION
    VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/format-annotation"] = Draft202012::Vocab::FORMAT_ANNOTATION
    VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/format-assertion"] = Draft202012::Vocab::FORMAT_ASSERTION
    VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/content"] = Draft202012::Vocab::CONTENT
    VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/meta-data"] = Draft202012::Vocab::META_DATA
    VOCABULARIES["https://spec.openapis.org/oas/3.1/vocab/base"] = OpenAPI31::Vocab::BASE

    VOCABULARIES.each_with_index do |(vocab, _keywords), index|
      VOCABULARY_ORDER[vocab] = index
    end

    # Register meta schemas for quick lookup
    META_SCHEMA_CALLABLES_BY_BASE_URI_STR["https://json-schema.org/draft/2020-12/schema"] = -> { draft202012 }
    META_SCHEMA_CALLABLES_BY_BASE_URI_STR["https://spec.openapis.org/oas/3.1/dialect/base"] = -> { openapi31 }
  end

  # Meta schema lookup
  META_SCHEMA_CALLABLES_BY_BASE_URI_STR = {} of String => Proc(Schema)

  # Call registration at load time
  register_vocabularies
end
