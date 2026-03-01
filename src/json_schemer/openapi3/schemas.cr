module JsonSchemer
  module OpenAPI3
    @@lock = Mutex.new(protection: :reentrant)

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
    # OpenAPI 3.1 URIs
    OAS_3_1_DIALECT_2024_10_25_URI     = URI.parse("https://spec.openapis.org/oas/3.1/dialect/2024-10-25")
    OAS_3_1_DIALECT_2024_11_10_URI     = URI.parse("https://spec.openapis.org/oas/3.1/dialect/2024-11-10")
    OAS_3_1_DIALECT_BASE_URI           = URI.parse("https://spec.openapis.org/oas/3.1/dialect/base")
    OAS_3_1_META_2024_10_25_URI        = URI.parse("https://spec.openapis.org/oas/3.1/meta/2024-10-25")
    OAS_3_1_META_2024_11_10_URI        = URI.parse("https://spec.openapis.org/oas/3.1/meta/2024-11-10")
    OAS_3_1_META_BASE_URI              = URI.parse("https://spec.openapis.org/oas/3.1/meta/base")
    OAS_3_1_SCHEMA_BASE_2022_10_07_URI = URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2022-10-07")
    OAS_3_1_SCHEMA_BASE_2024_11_14_URI = URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2024-11-14")
    OAS_3_1_SCHEMA_BASE_2025_09_15_URI = URI.parse("https://spec.openapis.org/oas/3.1/schema-base/2025-09-15")
    OAS_3_1_SCHEMA_2022_10_07_URI      = URI.parse("https://spec.openapis.org/oas/3.1/schema/2022-10-07")
    OAS_3_1_SCHEMA_2024_11_14_URI      = URI.parse("https://spec.openapis.org/oas/3.1/schema/2024-11-14")
    OAS_3_1_SCHEMA_2025_09_15_URI      = URI.parse("https://spec.openapis.org/oas/3.1/schema/2025-09-15")

    # OpenAPI 3.2 URIs
    OAS_3_2_DIALECT_2025_09_17_URI     = URI.parse("https://spec.openapis.org/oas/3.2/dialect/2025-09-17")
    OAS_3_2_META_2025_09_17_URI        = URI.parse("https://spec.openapis.org/oas/3.2/meta/2025-09-17")
    OAS_3_2_SCHEMA_BASE_2025_09_17_URI = URI.parse("https://spec.openapis.org/oas/3.2/schema-base/2025-09-17")
    OAS_3_2_SCHEMA_2025_09_17_URI      = URI.parse("https://spec.openapis.org/oas/3.2/schema/2025-09-17")

    SCHEMA_SOURCES = {
      OAS_3_1_DIALECT_2024_10_25_URI     => OAS_3_1_DIALECT_2024_10_25_JSON,
      OAS_3_1_DIALECT_2024_11_10_URI     => OAS_3_1_DIALECT_2024_11_10_JSON,
      OAS_3_1_DIALECT_BASE_URI           => OAS_3_1_DIALECT_BASE_JSON,
      OAS_3_1_META_2024_10_25_URI        => OAS_3_1_META_2024_10_25_JSON,
      OAS_3_1_META_2024_11_10_URI        => OAS_3_1_META_2024_11_10_JSON,
      OAS_3_1_META_BASE_URI              => OAS_3_1_META_BASE_JSON,
      OAS_3_1_SCHEMA_BASE_2022_10_07_URI => OAS_3_1_SCHEMA_BASE_2022_10_07_JSON,
      OAS_3_1_SCHEMA_BASE_2024_11_14_URI => OAS_3_1_SCHEMA_BASE_2024_11_14_JSON,
      OAS_3_1_SCHEMA_BASE_2025_09_15_URI => OAS_3_1_SCHEMA_BASE_2025_09_15_JSON,
      OAS_3_1_SCHEMA_2022_10_07_URI      => OAS_3_1_SCHEMA_2022_10_07_JSON,
      OAS_3_1_SCHEMA_2024_11_14_URI      => OAS_3_1_SCHEMA_2024_11_14_JSON,
      OAS_3_1_SCHEMA_2025_09_15_URI      => OAS_3_1_SCHEMA_2025_09_15_JSON,
      OAS_3_2_DIALECT_2025_09_17_URI     => OAS_3_2_DIALECT_2025_09_17_JSON,
      OAS_3_2_META_2025_09_17_URI        => OAS_3_2_META_2025_09_17_JSON,
      OAS_3_2_SCHEMA_BASE_2025_09_17_URI => OAS_3_2_SCHEMA_BASE_2025_09_17_JSON,
      OAS_3_2_SCHEMA_2025_09_17_URI      => OAS_3_2_SCHEMA_2025_09_17_JSON,
    }

    # OpenAPI formats
    FORMATS = {
      "int32" => ->(instance : JSON::Any, _format : String) {
        return true unless Draft202012::Vocab::Validation::Type.valid_integer?(instance)
        value = instance.raw.as(Number).to_i64
        value >= Int32::MIN && value <= Int32::MAX
      },
      "int64" => ->(instance : JSON::Any, _format : String) {
        return true unless Draft202012::Vocab::Validation::Type.valid_integer?(instance)
        # Any value that fits in Int64 is valid for int64 format
        # If it parsed as Int64, it fits in Int64.
        true
      },
      "float" => ->(instance : JSON::Any, _format : String) {
        return true unless instance.raw.is_a?(Number)
        true # Any number is valid for float
      },
      "double" => ->(instance : JSON::Any, _format : String) {
        return true unless instance.raw.is_a?(Number)
        true # Any number is valid for double
      },
      "password" => ->(_instance : JSON::Any, _format : String) {
        true
      },
    } of String => Format::FormatValidator

    # Schema registry - caches loaded schemas
    class_getter schemas = LRUCache(URI, JSONHash).new(1000)

    # Schema resolver that looks up by URI
    SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
      resolve_schema(uri)
    }

    def self.resolve_schema(uri : URI) : JSONHash?
      if schema = schemas.get(uri)
        return schema
      end

      json = SCHEMA_SOURCES[uri]?
      meta_schema = JsonSchemer::Draft202012::Meta::SCHEMAS[uri]?

      if json
        parsed_schema = JSONHash.from_json(json)
        @@lock.synchronize do
          schemas.get(uri) || schemas.set(uri, parsed_schema)
        end
      elsif meta_schema
        @@lock.synchronize do
          schemas.get(uri) || schemas.set(uri, meta_schema)
        end
      end
    end

    # Resolves a schema by URI, raising an error if not found
    def self.resolve_schema!(uri : URI) : JSONHash
      resolve_schema(uri) || raise "Schema not found: #{uri}"
    end

    @@document_schemas = {} of URI => Schema
    @@entrypoint_by_dialect : Hash(String, URI)?

    # Get the cached document schema for a given entrypoint URI
    def self.document_schema(entrypoint_uri : URI) : Schema
      @@document_schemas[entrypoint_uri]? || @@lock.synchronize do
        @@document_schemas[entrypoint_uri] ||= Schema.new(
          resolve_schema!(entrypoint_uri),
          ref_resolver: SCHEMAS_RESOLVER,
          regexp_resolver: "ecma"
        )
      end
    end

    # Entrypoint schemas for document validation, keyed by jsonSchemaDialect value
    # Each entry contains the schema-base URI for that dialect
    def self.entrypoint_by_dialect : Hash(String, URI)
      @@entrypoint_by_dialect || @@lock.synchronize do
        @@entrypoint_by_dialect ||= {
          # 3.1 json schema dialects to schema-base mapping
          OAS_3_1_DIALECT_BASE_URI.to_s       => OAS_3_1_SCHEMA_BASE_2022_10_07_URI,
          OAS_3_1_DIALECT_2024_10_25_URI.to_s => OAS_3_1_SCHEMA_BASE_2024_11_14_URI,
          OAS_3_1_DIALECT_2024_11_10_URI.to_s => OAS_3_1_SCHEMA_BASE_2025_09_15_URI,
          # 3.2 json schema dialects to schema-base mapping
          OAS_3_2_DIALECT_2025_09_17_URI.to_s => OAS_3_2_SCHEMA_BASE_2025_09_17_URI,
        } of String => URI
      end
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
          return OAS_3_1_SCHEMA_BASE_2025_09_15_URI
        when /\A3\.2\./
          return OAS_3_2_SCHEMA_BASE_2025_09_17_URI
        end
      end

      # Default to latest 3.2
      OAS_3_2_SCHEMA_BASE_2025_09_17_URI
    end

    # Get the dialect schema URI for a given OpenAPI version
    def self.select_dialect_schema(version : String?) : URI
      case version
      when /\A3\.1\./
        OAS_3_1_DIALECT_2024_11_10_URI
      when /\A3\.2\./
        OAS_3_2_DIALECT_2025_09_17_URI
      else
        OAS_3_2_DIALECT_2025_09_17_URI
      end
    end
  end
end
