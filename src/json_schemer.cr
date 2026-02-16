require "json"
require "uri"
require "big"
require "socket"
require "http/client"
require "base64"
require "log"

require "hana"
{% if flag?(:with_simpleidn) %}
  require "simpleidn"
{% end %}

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
require "./json_schemer/openapi3/vocab/base"
require "./json_schemer/openapi3/vocab"
# Load OpenAPI schemas before other OpenAPI modules
require "./json_schemer/openapi3/schemas"
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

  # Default ref resolver that raises `UnknownRef` for any external reference.
  DEFAULT_REF_RESOLVER = ->(uri : URI) : JSONHash? {
    raise UnknownRef.new(uri.to_s)
  }

  # Ref resolver that fetches schemas via HTTP(S).
  #
  # Uses `HTTP::Client` to fetch the content.
  NET_HTTP_REF_RESOLVER = ->(uri : URI) : JSONHash? {
    response = HTTP::Client.get(uri)
    JSONHash.from_json(response.body)
  }

  # Ref resolver that reads schemas from the local filesystem.
  #
  # Expects `file://` URIs.
  FILE_URI_REF_RESOLVER = ->(uri : URI) : JSONHash? {
    raise InvalidFileURI.new("must use `file` scheme") unless uri.scheme == "file"
    host = uri.host
    raise InvalidFileURI.new("cannot have a host (use `file:///`)") if host && !host.empty?
    path = uri.path
    raise InvalidFileURI.new("must have a path") unless path
    path = path[1..] if path.matches?(WINDOWS_URI_PATH_REGEX)
    JSONHash.from_json(File.read(URI.decode(path)))
  }

  # Regexp resolver using Ruby/Crystal standard `Regex` (PCRE).
  RUBY_REGEXP_RESOLVER = ->(pattern : String) : Regex? {
    Regex.new(pattern)
  }

  # Regexp resolver that converts ECMA-262 patterns to Crystal `Regex`.
  #
  # Uses `EcmaRegexp` for conversion.
  ECMA_REGEXP_RESOLVER = ->(pattern : String) : Regex? {
    Regex.new(EcmaRegexp.crystal_equivalent(pattern))
  }

  # Creates a new `Schema` instance from the given schema definition.
  #
  # The schema can be provided as a `String` (JSON), a `Hash` (already parsed JSON), or a `Path` (path to a schema file).
  #
  # ### Examples
  #
  # From a JSON string:
  # ```
  # schema = JsonSchemer.schema(%q({
  #   "type": "object",
  #   "properties": {
  #     "age": {"type": "integer", "minimum": 0}
  #   }
  # }))
  # ```
  #
  # From a Hash:
  # ```
  # schema = JsonSchemer.schema({
  #   "type"      => JSON::Any.new("string"),
  #   "minLength" => JSON::Any.new(5_i64),
  # })
  # ```
  #
  # From a file:
  # ```
  # schema = JsonSchemer.schema(Path.new("schemas/user.json"))
  # ```
  #
  # ### Options
  #
  # * *base_uri*: The base URI for resolving relative references. Automatically set when loading from a `Path`.
  # * *meta_schema*: The meta-schema to use for validation. Defaults to Draft 2020-12.
  # * *ref_resolver*: A proc or string to resolve external `$ref`s. See `NET_HTTP_REF_RESOLVER` and `FILE_URI_REF_RESOLVER`.
  # * *regexp_resolver*: "ecma" (for JS compatibility) or "ruby" (default).
  # * *format*: If `true`, enables format validation (default is annotation-only).
  # * *access_mode*: "read" or "write" to validation `readOnly`/`writeOnly` properties.
  #
  # See `Configuration` for more details on available options.
  def self.schema(
    schema : String | JSONHash | Path,
    base_uri : URI? = nil,
    meta_schema : Schema | String | Nil = nil,
    vocabulary : Hash(String, Bool)? = nil,
    format : Bool? = nil,
    formats : Hash(String, Format::FormatValidator)? = nil,
    content_encodings : Hash(String, Content::ContentEncodingValidator)? = nil,
    content_media_types : Hash(String, Content::ContentMediaTypeValidator)? = nil,
    keywords : Hash(String, Proc(JSON::Any, JSON::Any, String, Keyword, Bool | Array(String)))? = nil,
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
      insert_property_defaults: insert_property_defaults,
      property_default_resolver: property_default_resolver,
      ref_resolver: resolved_ref_resolver,
      regexp_resolver: regexp_resolver,
      output_format: output_format,
      resolve_enumerators: resolve_enumerators,
      access_mode: access_mode
    )
  end

  # Checks if the given schema definition is valid against its meta-schema.
  #
  # This is useful to verify that a schema is syntactically correct before using it.
  #
  # ```
  # JsonSchemer.valid_schema?(%q({"type": "string"}))       # => true
  # JsonSchemer.valid_schema?(%q({"type": "invalid_type"})) # => false
  # ```
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

  # Validates the given schema definition against its meta-schema and returns the validation result.
  #
  # Returns a Hash containing the validation result. If the schema is invalid, detailed errors are provided.
  #
  # ```
  # result = JsonSchemer.validate_schema(%q({"type": "invalid_type"}))
  # result["valid"] # => false
  # ```
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

  # Get OpenAPI 3.1 dialect schema (for validating schemas with $schema: https://spec.openapis.org/oas/3.1/dialect/...)
  # Get OpenAPI 3.1 dialect 2024-11-10 schema
  def self.openapi31_dialect_2024_11_10 : Schema
    @@openapi31_dialect_2024_11_10 ||= Schema.new(
      OpenAPI3.resolve_schema!(OpenAPI3::OAS_3_1_DIALECT_2024_11_10_URI),
      base_uri: OpenAPI3::OAS_3_1_DIALECT_2024_11_10_URI,
      formats: OpenAPI3::FORMATS,
      ref_resolver: OpenAPI3::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # Get OpenAPI 3.1 dialect base schema
  def self.openapi31_dialect_base : Schema
    @@openapi31_dialect_base ||= Schema.new(
      OpenAPI3.resolve_schema!(OpenAPI3::OAS_3_1_DIALECT_BASE_URI),
      base_uri: OpenAPI3::OAS_3_1_DIALECT_BASE_URI,
      formats: OpenAPI3::FORMATS,
      ref_resolver: OpenAPI3::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # Get OpenAPI 3.1 dialect 2024-10-25 schema
  def self.openapi31_dialect_2024_10_25 : Schema
    @@openapi31_dialect_2024_10_25 ||= Schema.new(
      OpenAPI3.resolve_schema!(OpenAPI3::OAS_3_1_DIALECT_2024_10_25_URI),
      base_uri: OpenAPI3::OAS_3_1_DIALECT_2024_10_25_URI,
      formats: OpenAPI3::FORMATS,
      ref_resolver: OpenAPI3::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # Get OpenAPI 3.1 document schema (entrypoint for validating OpenAPI 3.1 documents)
  # Uses the appropriate schema-base based on jsonSchemaDialect or openapi version
  def self.openapi31_document : Schema
    @@openapi31_document ||= Schema.new(
      OpenAPI3.resolve_schema!(OpenAPI3::OAS_3_1_SCHEMA_BASE_2025_09_15_URI),
      ref_resolver: OpenAPI3::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # Get OpenAPI 3.2 dialect schema
  # Get OpenAPI 3.2 dialect 2025-09-17 schema
  def self.openapi32_dialect_2025_09_17 : Schema
    @@openapi32_dialect_2025_09_17 ||= Schema.new(
      OpenAPI3.resolve_schema!(OpenAPI3::OAS_3_2_DIALECT_2025_09_17_URI),
      base_uri: OpenAPI3::OAS_3_2_DIALECT_2025_09_17_URI,
      formats: OpenAPI3::FORMATS,
      ref_resolver: OpenAPI3::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # Get OpenAPI 3.2 document schema (alias for openapi3_document)
  def self.openapi32_document : Schema
    @@openapi32_document ||= Schema.new(
      OpenAPI3.resolve_schema!(OpenAPI3::OAS_3_2_SCHEMA_BASE_2025_09_17_URI),
      ref_resolver: OpenAPI3::SCHEMAS_RESOLVER,
      regexp_resolver: "ecma"
    )
  end

  # Get OpenAPI 3.x document schema (uses entrypoint selection based on document content)
  def self.openapi3_document : Schema
    openapi32_document
  end

  # Creates an `OpenAPI` handler for the given OpenAPI document.
  #
  # Supports OpenAPI 3.1 documents.
  #
  # ```
  # document = JSON.parse(File.read("openapi.json")).as_h
  # openapi = JsonSchemer.openapi(document)
  #
  # # Validate the document itself
  # openapi.valid?
  #
  # # Get a schema component
  # user_schema = openapi.schema("User")
  # ```
  def self.openapi(document : JSONHash, **options) : OpenAPI
    OpenAPI.new(document, **options)
  end

  # Global configuration
  def self.configuration : Configuration
    @@configuration ||= Configuration.new
  end

  # Configures global defaults for `JsonSchemer`.
  #
  # ```
  # JsonSchemer.configure do |config|
  #   config.output_format = "basic"
  #   config.format = true
  # end
  # ```
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
        resolved_schema = FILE_URI_REF_RESOLVER.call(resolved_uri)
        raise InvalidRefResolution.new("Failed to resolve file schema: #{resolved_uri}") unless resolved_schema
        {resolved_schema, base_uri || resolved_uri, ref_resolver}
      else
        cached = CachedRefResolver.new(&FILE_URI_REF_RESOLVER)
        resolved_schema = cached.call(resolved_uri)
        raise InvalidRefResolution.new("Failed to resolve file schema: #{resolved_uri}") unless resolved_schema
        {resolved_schema, base_uri || resolved_uri, cached.to_proc}
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
    VOCABULARIES["https://spec.openapis.org/oas/3.1/vocab/base"] = OpenAPI3::Vocab::BASE
    VOCABULARIES["https://spec.openapis.org/oas/3.2/vocab/base"] = OpenAPI3::Vocab::BASE

    VOCABULARIES.each_with_index do |(vocab, _keywords), index|
      VOCABULARY_ORDER[vocab] = index
    end

    # Register meta schemas for quick lookup
    META_SCHEMA_CALLABLES_BY_BASE_URI_STR[Draft202012::ID] = -> { draft202012 }
    META_SCHEMA_CALLABLES_BY_BASE_URI_STR[OpenAPI3::OAS_3_1_DIALECT_BASE_URI.to_s] = -> { openapi31_dialect_base }
    META_SCHEMA_CALLABLES_BY_BASE_URI_STR[OpenAPI3::OAS_3_1_DIALECT_2024_10_25_URI.to_s] = -> { openapi31_dialect_2024_10_25 }
    META_SCHEMA_CALLABLES_BY_BASE_URI_STR[OpenAPI3::OAS_3_1_DIALECT_2024_11_10_URI.to_s] = -> { openapi31_dialect_2024_11_10 }
    META_SCHEMA_CALLABLES_BY_BASE_URI_STR[OpenAPI3::OAS_3_2_DIALECT_2025_09_17_URI.to_s] = -> { openapi32_dialect_2025_09_17 }
  end

  # Meta schema lookup
  META_SCHEMA_CALLABLES_BY_BASE_URI_STR = {} of String => Proc(Schema)

  # Call registration at load time
  register_vocabularies
end
