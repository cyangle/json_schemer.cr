module JsonSchemer
  module OpenAPI31
    BASE_URI = URI.parse("https://spec.openapis.org/oas/3.1/dialect/base")

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
      "password" => ->(instance : JSON::Any, _format : String) {
        true
      },
    } of String => Format::FormatValidator

    SCHEMA = JSONHash.from_json(<<-JSON
    {
      "$id": "https://spec.openapis.org/oas/3.1/dialect/base",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "title": "OpenAPI 3.1 Schema Object Dialect",
      "description": "A JSON Schema dialect describing schemas found in OpenAPI documents",
      "$vocabulary": {
        "https://json-schema.org/draft/2020-12/vocab/core": true,
        "https://json-schema.org/draft/2020-12/vocab/applicator": true,
        "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
        "https://json-schema.org/draft/2020-12/vocab/validation": true,
        "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
        "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
        "https://json-schema.org/draft/2020-12/vocab/content": true,
        "https://spec.openapis.org/oas/3.1/vocab/base": false
      },
      "$dynamicAnchor": "meta",
      "allOf": [
        { "$ref": "https://json-schema.org/draft/2020-12/schema" },
        { "$ref": "https://spec.openapis.org/oas/3.1/meta/base" }
      ]
    }
    JSON
    )

    module Meta
      BASE = JSONHash.from_json(<<-JSON
      {
        "$id": "https://spec.openapis.org/oas/3.1/meta/base",
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "OAS Base vocabulary",
        "description": "A JSON Schema Vocabulary used in the OpenAPI Schema Dialect",
        "$vocabulary": {
          "https://spec.openapis.org/oas/3.1/vocab/base": true
        },
        "$dynamicAnchor": "meta",
        "type": ["object", "boolean"],
        "properties": {
          "example": true,
          "discriminator": {
            "type": "object",
            "properties": {
              "propertyName": { "type": "string" },
              "mapping": {
                "type": "object",
                "additionalProperties": { "type": "string" }
              }
            },
            "required": ["propertyName"]
          },
          "externalDocs": {
            "type": "object",
            "properties": {
              "url": { "type": "string", "format": "uri-reference" },
              "description": { "type": "string" }
            },
            "required": ["url"]
          },
          "xml": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "namespace": { "type": "string", "format": "uri" },
              "prefix": { "type": "string" },
              "attribute": { "type": "boolean" },
              "wrapped": { "type": "boolean" }
            }
          }
        }
      }
      JSON
      )

      SCHEMAS = Draft202012::Meta::SCHEMAS.merge({
        Draft202012::BASE_URI                                    => Draft202012::SCHEMA,
        URI.parse("https://spec.openapis.org/oas/3.1/meta/base") => BASE,
      })

      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        SCHEMAS[uri]?
      }
    end
  end
end
