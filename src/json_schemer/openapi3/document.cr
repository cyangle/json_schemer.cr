module JsonSchemer
  module OpenAPI3
    module Document
      SCHEMA_BASE_ID  = "json-schemer://openapi3/schema-base"

      DIALECTS = [
        JsonSchemer::OpenAPI3::BASE_ID_3_2,
        JsonSchemer::OpenAPI3::BASE_ID_3_1,
        JsonSchemer::Draft202012::ID,
      ]
      DEFAULT_DIALECT = DIALECTS.first
      OTHER_DIALECTS  = DIALECTS[1..-1]

      def self.dialect_schema(dialect : String)
        schema_ref = if dialect.includes?("3.1")
                       "https://spec.openapis.org/oas/3.1/schema/2025-09-15"
                     else
                       "https://spec.openapis.org/oas/3.2/schema/2025-09-17"
                     end
        {
          "$id"   => JSON::Any.new(dialect.hash.to_s),
          "$ref"  => JSON::Any.new(schema_ref),
          "$defs" => JSON::Any.new({
            "schema" => JSON::Any.new({
              "$dynamicAnchor" => JSON::Any.new("meta"),
              "properties"     => JSON::Any.new({
                "$schema" => JSON::Any.new({
                  "$ref" => JSON::Any.new("#{SCHEMA_BASE_ID}#/$defs/dialect"),
                }),
              }),
              "allOf" => JSON::Any.new([
                JSON::Any.new({
                  "if" => JSON::Any.new({
                    "properties" => JSON::Any.new({
                      "$schema" => JSON::Any.new({
                        "const" => JSON::Any.new(dialect),
                      }),
                    }),
                  }),
                  "then" => JSON::Any.new({
                    "$ref" => JSON::Any.new(dialect),
                  }),
                }),
              ] + (DIALECTS - [dialect]).map { |other_dialect|
                JSON::Any.new({
                  "if" => JSON::Any.new({
                    "type"       => JSON::Any.new("object"),
                    "required"   => JSON::Any.new([JSON::Any.new("$schema")]),
                    "properties" => JSON::Any.new({
                      "$schema" => JSON::Any.new({
                        "const" => JSON::Any.new(other_dialect),
                      }),
                    }),
                  }),
                  "then" => JSON::Any.new({
                    "$ref" => JSON::Any.new(other_dialect),
                  }),
                })
              }),
            }),
          }),
        }
      end

      SCHEMA_BASE = {
        "$id"     => JSON::Any.new(SCHEMA_BASE_ID),
        "$schema" => JSON::Any.new("https://json-schema.org/draft/2020-12/schema"),
        "$defs"   => JSON::Any.new({
          "dialect" => JSON::Any.new({
            "enum" => JSON::Any.new(DIALECTS.map { |dialect| JSON::Any.new(dialect) }),
          }),
        }),
        "properties" => JSON::Any.new({
          "jsonSchemaDialect" => JSON::Any.new({
            "$ref" => JSON::Any.new("#/$defs/dialect"),
          }),
        }),
        "allOf" => JSON::Any.new([
          JSON::Any.new({
            "if" => JSON::Any.new({
              "anyOf" => JSON::Any.new([
                JSON::Any.new({
                  "required"   => JSON::Any.new([JSON::Any.new("jsonSchemaDialect")]),
                  "properties" => JSON::Any.new({"jsonSchemaDialect" => JSON::Any.new({"const" => JSON::Any.new(DEFAULT_DIALECT)})}),
                }),
                JSON::Any.new({
                  "not"        => JSON::Any.new({"required" => JSON::Any.new([JSON::Any.new("jsonSchemaDialect")])}),
                  "properties" => JSON::Any.new({"openapi" => JSON::Any.new({"pattern" => JSON::Any.new("^3\\.2\\.")})}),
                }),
              ]),
            }),
            "then" => JSON::Any.new(dialect_schema(DEFAULT_DIALECT)),
          }),
          JSON::Any.new({
            "if" => JSON::Any.new({
              "anyOf" => JSON::Any.new([
                JSON::Any.new({
                  "required"   => JSON::Any.new([JSON::Any.new("jsonSchemaDialect")]),
                  "properties" => JSON::Any.new({"jsonSchemaDialect" => JSON::Any.new({"const" => JSON::Any.new(JsonSchemer::OpenAPI3::DIALECT_ID_3_1)})}),
                }),
                JSON::Any.new({
                  "not"        => JSON::Any.new({"required" => JSON::Any.new([JSON::Any.new("jsonSchemaDialect")])}),
                  "properties" => JSON::Any.new({"openapi" => JSON::Any.new({"pattern" => JSON::Any.new("^3\\.1\\.")})}),
                }),
              ]),
            }),
            "then" => JSON::Any.new(dialect_schema(JsonSchemer::OpenAPI3::DIALECT_ID_3_1)),
          }),
        ] + (OTHER_DIALECTS - [JsonSchemer::OpenAPI3::DIALECT_ID_3_1]).map { |other_dialect|
          JSON::Any.new({
            "if" => JSON::Any.new({
              "required"   => JSON::Any.new([JSON::Any.new("jsonSchemaDialect")]),
              "properties" => JSON::Any.new({
                "jsonSchemaDialect" => JSON::Any.new({
                  "const" => JSON::Any.new(other_dialect),
                }),
              }),
            }),
            "then" => JSON::Any.new(dialect_schema(other_dialect)),
          })
        }),
      }

      # Adjusted to allow 3.1.x and 3.2.x
      SCHEMA_JSON_3_1 = {{ read_file("#{__DIR__}/openapi_3_1_schema.json") }}
      SCHEMA_3_1      = JSONHash.from_json(SCHEMA_JSON_3_1)
      SCHEMA_JSON_3_2 = {{ read_file("#{__DIR__}/openapi_3_2_schema.json") }}
      SCHEMA_3_2      = JSONHash.from_json(SCHEMA_JSON_3_2)

      SCHEMAS = OpenAPI3::Meta::SCHEMAS.merge(Draft202012::Meta::SCHEMAS).merge({
        OpenAPI3::BASE_URI_3_2                                           => OpenAPI3::SCHEMA_3_2,
        OpenAPI3::BASE_URI_3_1                                           => OpenAPI3::SCHEMA_3_1,
        URI.parse("https://spec.openapis.org/oas/3.2/schema/2025-09-17") => SCHEMA_3_2,
        URI.parse("https://spec.openapis.org/oas/3.1/schema/2025-09-15") => SCHEMA_3_1,
        Draft202012::BASE_URI                                            => Draft202012::SCHEMA,
      })

      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        SCHEMAS[uri]?
      }
    end
  end
end
