module JsonSchemer
  module OpenAPI32
    module Document
      DIALECTS = [
        OpenAPI32::BASE_URI.to_s,
        JsonSchemer::OPENAPI31_DIALECT_ID,
        Draft202012::BASE_URI.to_s,
        "https://json-schema.org/draft/2019-09/schema",
        "http://json-schema.org/draft-07/schema#",
        "http://json-schema.org/draft-06/schema#",
        "http://json-schema.org/draft-04/schema#",
      ]
      DEFAULT_DIALECT = DIALECTS.first
      OTHER_DIALECTS  = DIALECTS[1..-1]

      def self.dialect_schema(dialect : String)
        {
          "$id"   => JSON::Any.new(dialect.hash.to_s),
          "$ref"  => JSON::Any.new("https://spec.openapis.org/oas/3.2/schema/2025-09-17"),
          "$defs" => JSON::Any.new({
            "schema" => JSON::Any.new({
              "$dynamicAnchor" => JSON::Any.new("meta"),
              "properties"     => JSON::Any.new({
                "$schema" => JSON::Any.new({
                  "$ref" => JSON::Any.new("json-schemer://openapi32/schema-base#/$defs/dialect"),
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
        "$id"     => JSON::Any.new("json-schemer://openapi32/schema-base"),
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
              "properties" => JSON::Any.new({
                "jsonSchemaDialect" => JSON::Any.new({
                  "const" => JSON::Any.new(DEFAULT_DIALECT),
                }),
              }),
            }),
            "then" => JSON::Any.new(dialect_schema(DEFAULT_DIALECT)),
          }),
        ] + OTHER_DIALECTS.map { |other_dialect|
          JSON::Any.new({
            "if" => JSON::Any.new({
              "type"       => JSON::Any.new("object"),
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

      SCHEMA_JSON = {{ read_file("#{__DIR__}/schema.json") }}
      # Convert JSON::Any to Hash(String, JSON::Any)
      SCHEMA = JSON.parse(SCHEMA_JSON).as_h.tap do |schema|
        # Patch schema to allow OpenAPI 3.1 versions
        if props = schema["properties"]?.try(&.as_h)
          if openapi = props["openapi"]?.try(&.as_h)
            # Allow 3.1.x and 3.2.x
            # Original: ^3\\.2\\.\\d+(-.+)?$
            # New: ^3\\.(1|2)\\.\\d+(-.+)?$
            openapi["pattern"] = JSON::Any.new("^3\\.(1|2)\\.\\d+(-.+)?$")
          end
        end
      end

      SCHEMAS = OpenAPI32::Meta::SCHEMAS.merge(Draft202012::Meta::SCHEMAS).merge({
        URI.parse("https://spec.openapis.org/oas/3.2/schema/2025-09-17") => SCHEMA,
        OpenAPI32::BASE_URI                                              => OpenAPI32::SCHEMA,
        URI.parse(JsonSchemer::OPENAPI31_DIALECT_ID)                     => OpenAPI32::SCHEMA_3_1,
        Draft202012::BASE_URI                                            => Draft202012::SCHEMA,
        URI.parse("json-schemer://openapi32/schema-base")                => SCHEMA_BASE,
      })

      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        SCHEMAS[uri]?
      }
    end
  end
end
