module JsonSchemer
  # OpenAPI document handler
  class OpenAPI
    @document : JSONHash
    @document_schema : Schema
    @schema : Schema

    def initialize(
      document : JSONHash,
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
    )
      @document = document

      version = document["openapi"]?.try(&.as_s)
      case version
      when /\A3\.1\.\d+\z/
        @document_schema = JsonSchemer.openapi31_document
        resolved_meta_schema = document["jsonSchemaDialect"]?.try(&.as_s) || OpenAPI31::BASE_URI.to_s
      else
        raise UnsupportedOpenAPIVersion.new(version.to_s)
      end

      @schema = Schema.new(
        JSON::Any.new(@document.transform_values { |v| v }),
        meta_schema: resolved_meta_schema,
        base_uri: base_uri,
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
        ref_resolver: ref_resolver,
        regexp_resolver: regexp_resolver,
        output_format: output_format,
        resolve_enumerators: resolve_enumerators,
        access_mode: access_mode
      )
    end

    # Checks if the OpenAPI document itself is valid against the OpenAPI specification.
    #
    # ```
    # openapi = JsonSchemer.openapi(document)
    # if openapi.valid?
    #   puts "OpenAPI document is valid"
    # end
    # ```
    def valid? : Bool
      @document_schema.valid?(JSON::Any.new(@document.transform_values { |v| v }))
    end

    # Validates the OpenAPI document and returns the validation result.
    #
    # The result format is determined by `output_format` (default: "classic").
    #
    # ```
    # result = openapi.validate
    # unless result["valid"].as_bool
    #   puts "Invalid OpenAPI document:"
    #   puts result["errors"]
    # end
    # ```
    def validate(output_format : String = "classic") : Hash(String, JSON::Any)
      @document_schema.validate(JSON::Any.new(@document.transform_values { |v| v }), output_format: output_format)
    end

    # Resolves a reference URI within the OpenAPI document.
    #
    # ```
    # user_schema = openapi.ref("#/components/schemas/User")
    # ```
    def ref(value : String) : Schema
      @schema.ref(value)
    end

    # Retrieves a schema definition from `#/components/schemas`.
    #
    # Shortcut for `ref("#/components/schemas/#{name}")`.
    #
    # ```
    # user_schema = openapi.schema("User")
    # ```
    def schema(name : String) : Schema
      ref("#/components/schemas/#{name}")
    end
  end
end
