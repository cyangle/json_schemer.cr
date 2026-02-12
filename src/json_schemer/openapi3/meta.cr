module JsonSchemer
  module OpenAPI3
    BASE_ID_3_2  = "https://spec.openapis.org/oas/3.2/dialect/base"
    BASE_ID_3_1  = "https://spec.openapis.org/oas/3.1/dialect/base"
    BASE_URI_3_2 = URI.parse(BASE_ID_3_2)
    BASE_URI_3_1 = URI.parse(BASE_ID_3_1)

    DIALECT_ID_3_2  = "https://spec.openapis.org/oas/3.2/dialect/2025-09-17"
    DIALECT_ID_3_1  = "https://spec.openapis.org/oas/3.1/dialect/2025-09-15"
    DIALECT_URI_3_2 = URI.parse(DIALECT_ID_3_2)
    DIALECT_URI_3_1 = URI.parse(DIALECT_ID_3_1)

    BASE_VOCAB_ID_3_2 = "https://spec.openapis.org/oas/3.2/vocab/base"
    BASE_VOCAB_ID_3_1 = "https://spec.openapis.org/oas/3.1/vocab/base"

    BASE_META_ID_3_2  = "https://spec.openapis.org/oas/3.2/meta/base"
    BASE_META_ID_3_1  = "https://spec.openapis.org/oas/3.1/meta/base"
    BASE_META_URI_3_2 = URI.parse(BASE_META_ID_3_2)
    BASE_META_URI_3_1 = URI.parse(BASE_META_ID_3_1)

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

    SCHEMA_3_2 = JSONHash.from_json(<<-JSON
      {
        "$id": "#{BASE_ID_3_2}",
        "$schema": "#{JsonSchemer::Draft202012::ID}",
        "title": "OpenAPI 3.2 Schema Object Dialect",
        "description": "A JSON Schema dialect describing schemas found in OpenAPI documents",
        "$vocabulary": {
          "https://json-schema.org/draft/2020-12/vocab/core": true,
          "https://json-schema.org/draft/2020-12/vocab/applicator": true,
          "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
          "https://json-schema.org/draft/2020-12/vocab/validation": true,
          "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
          "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
          "https://json-schema.org/draft/2020-12/vocab/content": true,
          "#{BASE_VOCAB_ID_3_2}": false
        },
        "$dynamicAnchor": "meta",
        "allOf": [
          { "$ref": "#{JsonSchemer::Draft202012::ID}" },
          { "$ref": "#{BASE_META_ID_3_2}" }
        ]
      }
      JSON
    )

    SCHEMA_3_1 = JSONHash.from_json(<<-JSON
      {
        "$id": "#{BASE_ID_3_1}",
        "$schema": "#{JsonSchemer::Draft202012::ID}",
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
          "#{BASE_VOCAB_ID_3_1}": false
        },

      "$dynamicAnchor": "meta",
      "allOf": [
        { "$ref": "#{JsonSchemer::Draft202012::ID}" },
        { "$ref": "#{BASE_META_ID_3_1}" }
      ]
    }
    JSON
    )

    module Meta
      BASE_3_2 = JSONHash.from_json(<<-JSON
      {
        "$id": "#{BASE_META_ID_3_2}",
        "$schema": "#{JsonSchemer::Draft202012::ID}",
        "title": "OAS Base vocabulary",
        "description": "A JSON Schema Vocabulary used in the OpenAPI Schema Dialect",
        "$vocabulary": {
          "#{BASE_VOCAB_ID_3_2}": true
        },
        "$dynamicAnchor": "meta",
        "type": ["object", "boolean"],
        "properties": {
          "example": true,
          "extensible": {
            "patternProperties": {
              "^x-": true
            }
          },
          "discriminator": {
            "type": "object",
            "properties": {
              "propertyName": { "type": "string" },
              "mapping": {
                "type": "object",
                "additionalProperties": { "type": "string" }
              },
              "defaultMapping": { "type": "string" }
            },
            "unevaluatedProperties": false
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

      BASE_3_1 = JSONHash.from_json(<<-JSON
      {
        "$id": "#{BASE_META_ID_3_1}",
        "$schema": "#{JsonSchemer::Draft202012::ID}",
        "title": "OAS Base vocabulary",
        "description": "A JSON Schema Vocabulary used in the OpenAPI Schema Dialect",
        "$vocabulary": {
          "#{BASE_VOCAB_ID_3_1}": true
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
        Draft202012::BASE_URI => Draft202012::SCHEMA,
        BASE_META_URI_3_2     => BASE_3_2,
        BASE_META_URI_3_1     => BASE_3_1,
      })

      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        SCHEMAS[uri]?
      }
    end
  end
end
