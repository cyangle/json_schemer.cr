module JsonSchemer
  module OpenAPI31
    module Document
      DIALECTS = [
        OpenAPI31::BASE_URI.to_s,
        Draft202012::BASE_URI.to_s,
        # Unsupported drafts omitted from logic but kept in list if needed for enum validation?
        # If I remove them from here, validation might fail if the document uses them.
        # But if I keep them, they are just strings in enum.
        "https://json-schema.org/draft/2019-09/schema",
        "http://json-schema.org/draft-07/schema#",
        "http://json-schema.org/draft-06/schema#",
        "http://json-schema.org/draft-04/schema#",
      ]
      DEFAULT_DIALECT = DIALECTS.first
      OTHER_DIALECTS  = DIALECTS[1..-1]

      def self.dialect_schema(dialect : String)
        {
          "$id"   => JSON::Any.new(dialect.hash.to_s), # object_id in Ruby, hash in Crystal
          "$ref"  => JSON::Any.new("https://spec.openapis.org/oas/3.1/schema/2022-10-07"),
          "$defs" => JSON::Any.new({
            "schema" => JSON::Any.new({
              "$dynamicAnchor" => JSON::Any.new("meta"),
              "properties"     => JSON::Any.new({
                "$schema" => JSON::Any.new({
                  "$ref" => JSON::Any.new("json-schemer://openapi31/schema-base#/$defs/dialect"),
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
        "$id"     => JSON::Any.new("json-schemer://openapi31/schema-base"),
        "$schema" => JSON::Any.new("https://json-schema.org/draft/2020-12/schema"),
        "$defs"   => JSON::Any.new({
          "dialect" => JSON::Any.new({
            "enum" => JSON::Any.new(DIALECTS.map { |d| JSON::Any.new(d) }),
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
      SCHEMA = JSON.parse(SCHEMA_JSON).as_h

      SCHEMAS = OpenAPI31::Meta::SCHEMAS.merge(Draft202012::Meta::SCHEMAS).merge({
        URI.parse("https://spec.openapis.org/oas/3.1/schema/2022-10-07") => SCHEMA,
        OpenAPI31::BASE_URI                                              => OpenAPI31::SCHEMA,
        Draft202012::BASE_URI                                            => Draft202012::SCHEMA,
        # json-schemer://openapi31/schema-base is needed
        URI.parse("json-schemer://openapi31/schema-base") => SCHEMA_BASE,
      })

      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        SCHEMAS[uri]?
      }
    end
  end
end
