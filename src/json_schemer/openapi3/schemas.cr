module JsonSchemer
  module OpenAPI3
    # Data files embedded at compile time - all files from data/oas directory
    # OpenAPI 3.1 files (only those referenced by build_entrypoint_by_dialect)
    OAS_3_1_DIALECT_2024_10_25_JSON     = {{ read_file("#{__DIR__}/../../../data/oas/3.1/dialect/2024-10-25") }}
    OAS_3_1_DIALECT_2024_11_10_JSON     = {{ read_file("#{__DIR__}/../../../data/oas/3.1/dialect/2024-11-10") }}
    OAS_3_1_DIALECT_BASE_JSON           = {{ read_file("#{__DIR__}/../../../data/oas/3.1/dialect/base") }}
    OAS_3_1_META_2024_10_25_JSON        = {{ read_file("#{__DIR__}/../../../data/oas/3.1/meta/2024-10-25") }}
    OAS_3_1_META_2024_11_10_JSON        = {{ read_file("#{__DIR__}/../../../data/oas/3.1/meta/2024-11-10") }}
    OAS_3_1_META_BASE_JSON              = {{ read_file("#{__DIR__}/../../../data/oas/3.1/meta/base") }}
    OAS_3_1_SCHEMA_BASE_2022_10_07_JSON = {{ read_file("#{__DIR__}/../../../data/oas/3.1/schema-base/2022-10-07") }}
    OAS_3_1_SCHEMA_BASE_2024_11_14_JSON = {{ read_file("#{__DIR__}/../../../data/oas/3.1/schema-base/2024-11-14") }}
    OAS_3_1_SCHEMA_BASE_2025_09_15_JSON = {{ read_file("#{__DIR__}/../../../data/oas/3.1/schema-base/2025-09-15") }}
    OAS_3_1_SCHEMA_2022_10_07_JSON      = {{ read_file("#{__DIR__}/../../../data/oas/3.1/schema/2022-10-07") }}
    OAS_3_1_SCHEMA_2024_11_14_JSON      = {{ read_file("#{__DIR__}/../../../data/oas/3.1/schema/2024-11-14") }}
    OAS_3_1_SCHEMA_2025_09_15_JSON      = {{ read_file("#{__DIR__}/../../../data/oas/3.1/schema/2025-09-15") }}

    # OpenAPI 3.2 files
    OAS_3_2_DIALECT_2025_09_17_JSON     = {{ read_file("#{__DIR__}/../../../data/oas/3.2/dialect/2025-09-17") }}
    OAS_3_2_META_2025_09_17_JSON        = {{ read_file("#{__DIR__}/../../../data/oas/3.2/meta/2025-09-17") }}
    OAS_3_2_SCHEMA_BASE_2025_09_17_JSON = {{ read_file("#{__DIR__}/../../../data/oas/3.2/schema-base/2025-09-17") }}
    OAS_3_2_SCHEMA_2025_09_17_JSON      = {{ read_file("#{__DIR__}/../../../data/oas/3.2/schema/2025-09-17") }}

    # Known URIs for OpenAPI schemas
    # Entrypoint schemas (schema-base) - used for document validation
    ENTRYPOINT_SCHEMA_3_1_URI = URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2025-09-15")
    ENTRYPOINT_SCHEMA_3_2_URI = URI.parse("https://spec.openapis.org/oas/3.2/schema-base/2025-09-17")

    # Dialect schemas (for @@openapi31, @@openapi32)
    DIALECT_SCHEMA_3_1_URI = URI.parse("https://spec.openapis.org/oas/3.1/dialect/2024-11-10")
    DIALECT_SCHEMA_3_2_URI = URI.parse("https://spec.openapis.org/oas/3.2/dialect/2025-09-17")

    # OpenAPI formats
    FORMATS = {
      "int32" => ->(instance : JSON::Any, _format : String) {
        !Draft202012::Vocab::Validation::Type.valid_integer?(instance) ||
        instance.raw.as(Number).to_i64.abs.bit_length < 32
      },
      "int64" => ->(instance : JSON::Any, _format : String) {
        !Draft202012::Vocab::Validation::Type.valid_integer?(instance) ||
        instance.raw.as(Number).to_i64.abs.bit_length < 64
      },
      "float" => ->(instance : JSON::Any, _format : String) {
        !instance.raw.is_a?(Number) || instance.raw.is_a?(Float64)
      },
      "double" => ->(instance : JSON::Any, _format : String) {
        !instance.raw.is_a?(Number) || instance.raw.is_a?(Float64)
      },
      "password" => ->(_instance : JSON::Any, _format : String) {
        true
      },
    } of String => Format::FormatValidator

    # Schema registry - populated at module load time
    class_getter schemas : Hash(URI, JSONHash) do
      load_schemas
    end

    # Schema resolver that looks up by URI
    SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
      OpenAPI3.schemas[uri]?
    }

    # Cached document validation schemas
    class_getter document_schema_3_1 : Schema do
      Schema.new(
        schemas[ENTRYPOINT_SCHEMA_3_1_URI],
        ref_resolver: SCHEMAS_RESOLVER,
        regexp_resolver: "ecma"
      )
    end

    class_getter document_schema_3_2 : Schema do
      Schema.new(
        schemas[ENTRYPOINT_SCHEMA_3_2_URI],
        ref_resolver: SCHEMAS_RESOLVER,
        regexp_resolver: "ecma"
      )
    end

    # Get the cached document schema for a given entrypoint URI
    def self.document_schema(entrypoint_uri : URI) : Schema
      if entrypoint_uri == ENTRYPOINT_SCHEMA_3_1_URI
        document_schema_3_1
      elsif entrypoint_uri == ENTRYPOINT_SCHEMA_3_2_URI
        document_schema_3_2
      else
        # Fallback for any other entrypoint (shouldn't happen in normal use)
        Schema.new(
          schemas[entrypoint_uri],
          ref_resolver: SCHEMAS_RESOLVER,
          regexp_resolver: "ecma"
        )
      end
    end

    # Entrypoint schemas for document validation, keyed by jsonSchemaDialect value
    # Each entry contains the schema-base URI for that dialect
    class_getter entrypoint_by_dialect : Hash(String, URI) do
      {
        # 3.1 json schema dialects to schema-base mapping
        "https://spec.openapis.org/oas/3.1/dialect/base"       => URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2022-10-07"),
        "https://spec.openapis.org/oas/3.1/dialect/2024-10-25" => URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2024-11-14"),
        "https://spec.openapis.org/oas/3.1/dialect/2024-11-10" => URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2025-09-15"),
        # 3.2 json schema dialects to schema-base mapping
        "https://spec.openapis.org/oas/3.2/dialect/2025-09-17" => URI.parse("https://spec.openapis.org/oas/3.2/schema-base/2025-09-17"),
      } of String => URI
    end

    # Select the appropriate entrypoint schema for an OpenAPI document
    # Returns the URI of the schema-base to use for validation
    def self.select_entrypoint(document : JSONHash) : URI
      # First, check if jsonSchemaDialect is explicitly set (takes precedence)
      if dialect = document["jsonSchemaDialect"]?.try(&.as_s?)
        # Check if it's an OpenAPI dialect we know about
        if entrypoint = entrypoint_by_dialect[dialect]?
          return entrypoint
        end
        # If it's a non-OpenAPI dialect (e.g., standard JSON Schema), fall back to version-based selection
      end

      # Fall back to openapi version
      if version = document["openapi"]?.try(&.as_s?)
        case version
        when /\A3\.1\./
          return ENTRYPOINT_SCHEMA_3_1_URI
        when /\A3\.2\./
          return ENTRYPOINT_SCHEMA_3_2_URI
        end
      end

      # Default to latest 3.2
      ENTRYPOINT_SCHEMA_3_2_URI
    end

    # Get the dialect schema URI for a given OpenAPI version
    def self.select_dialect_schema(version : String?) : URI
      case version
      when /\A3\.1\./
        DIALECT_SCHEMA_3_1_URI
      when /\A3\.2\./
        DIALECT_SCHEMA_3_2_URI
      else
        DIALECT_SCHEMA_3_2_URI
      end
    end

    # Load all schemas from embedded data files
    private def self.load_schemas : Hash(URI, JSONHash)
      schemas = {} of URI => JSONHash

      # Include Draft202012 meta schemas (needed for OpenAPI 3.1/3.2 $ref resolution)
      # The OpenAPI dialect schemas reference JSON Schema Draft 2020-12 vocabulary schemas
      JsonSchemer::Draft202012::Meta::SCHEMAS.each do |uri, schema|
        schemas[uri] = schema
      end

      # OpenAPI 3.1 schemas (only those referenced by build_entrypoint_by_dialect)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/dialect/2024-10-25")] = JSONHash.from_json(OAS_3_1_DIALECT_2024_10_25_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/dialect/2024-11-10")] = JSONHash.from_json(OAS_3_1_DIALECT_2024_11_10_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/dialect/base")] = JSONHash.from_json(OAS_3_1_DIALECT_BASE_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/meta/2024-10-25")] = JSONHash.from_json(OAS_3_1_META_2024_10_25_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/meta/2024-11-10")] = JSONHash.from_json(OAS_3_1_META_2024_11_10_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/meta/base")] = JSONHash.from_json(OAS_3_1_META_BASE_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2022-10-07")] = JSONHash.from_json(OAS_3_1_SCHEMA_BASE_2022_10_07_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2024-11-14")] = JSONHash.from_json(OAS_3_1_SCHEMA_BASE_2024_11_14_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2025-09-15")] = JSONHash.from_json(OAS_3_1_SCHEMA_BASE_2025_09_15_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/schema/2022-10-07")] = JSONHash.from_json(OAS_3_1_SCHEMA_2022_10_07_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/schema/2024-11-14")] = JSONHash.from_json(OAS_3_1_SCHEMA_2024_11_14_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.1/schema/2025-09-15")] = JSONHash.from_json(OAS_3_1_SCHEMA_2025_09_15_JSON)

      # OpenAPI 3.2 schemas
      schemas[URI.parse("https://spec.openapis.org/oas/3.2/dialect/2025-09-17")] = JSONHash.from_json(OAS_3_2_DIALECT_2025_09_17_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.2/meta/2025-09-17")] = JSONHash.from_json(OAS_3_2_META_2025_09_17_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.2/schema-base/2025-09-17")] = JSONHash.from_json(OAS_3_2_SCHEMA_BASE_2025_09_17_JSON)
      schemas[URI.parse("https://spec.openapis.org/oas/3.2/schema/2025-09-17")] = JSONHash.from_json(OAS_3_2_SCHEMA_2025_09_17_JSON)

      schemas
    end
  end
end
