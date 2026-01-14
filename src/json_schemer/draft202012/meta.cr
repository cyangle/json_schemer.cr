module JsonSchemer
  module Draft202012
    BASE_URI = URI.parse("https://json-schema.org/draft/2020-12/schema")

    FORMATS = {
      "date-time"             => Format::DATE_TIME,
      "date"                  => Format::DATE,
      "time"                  => Format::TIME,
      "duration"              => Format::DURATION,
      "email"                 => Format::EMAIL,
      "idn-email"             => Format::IDN_EMAIL,
      "hostname"              => Format::HOSTNAME,
      "idn-hostname"          => Format::IDN_HOSTNAME,
      "ipv4"                  => Format::IPV4,
      "ipv6"                  => Format::IPV6,
      "uri"                   => Format::URI_FORMAT,
      "uri-reference"         => Format::URI_REFERENCE,
      "iri"                   => Format::IRI,
      "iri-reference"         => Format::IRI_REFERENCE,
      "uuid"                  => Format::UUID_FORMAT,
      "uri-template"          => Format::URI_TEMPLATE,
      "json-pointer"          => Format::JSON_POINTER,
      "relative-json-pointer" => Format::RELATIVE_JSON_POINTER,
      "regex"                 => Format::REGEX,
    } of String => Format::FormatValidator

    CONTENT_ENCODINGS = {
      "base64" => Content::BASE64,
    } of String => Content::ContentEncodingValidator

    CONTENT_MEDIA_TYPES = {
      "application/json" => Content::JSON_MEDIA_TYPE,
    } of String => Content::ContentMediaTypeValidator

    SCHEMA = JSONHash.from_json(<<-JSON
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://json-schema.org/draft/2020-12/schema",
      "$vocabulary": {
        "https://json-schema.org/draft/2020-12/vocab/core": true,
        "https://json-schema.org/draft/2020-12/vocab/applicator": true,
        "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
        "https://json-schema.org/draft/2020-12/vocab/validation": true,
        "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
        "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
        "https://json-schema.org/draft/2020-12/vocab/content": true
      },
      "$dynamicAnchor": "meta",
      "title": "Core and Validation specifications meta-schema",
      "allOf": [
        {"$ref": "meta/core"},
        {"$ref": "meta/applicator"},
        {"$ref": "meta/unevaluated"},
        {"$ref": "meta/validation"},
        {"$ref": "meta/meta-data"},
        {"$ref": "meta/format-annotation"},
        {"$ref": "meta/content"}
      ],
      "type": ["object", "boolean"],
      "properties": {
        "definitions": {
          "type": "object",
          "additionalProperties": { "$dynamicRef": "#meta" },
          "deprecated": true,
          "default": {}
        },
        "dependencies": {
          "type": "object",
          "additionalProperties": {
            "anyOf": [
              { "$dynamicRef": "#meta" },
              { "$ref": "meta/validation#/$defs/stringArray" }
            ]
          },
          "deprecated": true,
          "default": {}
        }
      }
    }
    JSON
    )

    module Meta
      CORE = JSONHash.from_json(<<-JSON
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://json-schema.org/draft/2020-12/meta/core",
        "$dynamicAnchor": "meta",
        "title": "Core vocabulary meta-schema",
        "type": ["object", "boolean"],
        "properties": {
          "$id": {
            "type": "string",
            "format": "uri-reference",
            "pattern": "^[^#]*#?$"
          },
          "$schema": { "type": "string", "format": "uri" },
          "$ref": { "type": "string", "format": "uri-reference" },
          "$anchor": { "type": "string", "pattern": "^[A-Za-z_][-A-Za-z0-9._]*$" },
          "$dynamicRef": { "type": "string", "format": "uri-reference" },
          "$dynamicAnchor": { "type": "string", "pattern": "^[A-Za-z_][-A-Za-z0-9._]*$" },
          "$vocabulary": {
            "type": "object",
            "propertyNames": { "type": "string", "format": "uri" },
            "additionalProperties": { "type": "boolean" }
          },
          "$comment": { "type": "string" },
          "$defs": {
            "type": "object",
            "additionalProperties": { "$dynamicRef": "#meta" }
          }
        }
      }
      JSON
      )

      APPLICATOR = JSONHash.from_json(<<-JSON
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://json-schema.org/draft/2020-12/meta/applicator",
        "$dynamicAnchor": "meta",
        "title": "Applicator vocabulary meta-schema",
        "type": ["object", "boolean"],
        "properties": {
          "prefixItems": { "type": "array", "minItems": 1, "items": { "$dynamicRef": "#meta" } },
          "items": { "$dynamicRef": "#meta" },
          "contains": { "$dynamicRef": "#meta" },
          "additionalProperties": { "$dynamicRef": "#meta" },
          "properties": { "type": "object", "additionalProperties": { "$dynamicRef": "#meta" }, "default": {} },
          "patternProperties": { "type": "object", "additionalProperties": { "$dynamicRef": "#meta" }, "propertyNames": { "format": "regex" }, "default": {} },
          "dependentSchemas": { "type": "object", "additionalProperties": { "$dynamicRef": "#meta" }, "default": {} },
          "propertyNames": { "$dynamicRef": "#meta" },
          "if": { "$dynamicRef": "#meta" },
          "then": { "$dynamicRef": "#meta" },
          "else": { "$dynamicRef": "#meta" },
          "allOf": { "type": "array", "minItems": 1, "items": { "$dynamicRef": "#meta" } },
          "anyOf": { "type": "array", "minItems": 1, "items": { "$dynamicRef": "#meta" } },
          "oneOf": { "type": "array", "minItems": 1, "items": { "$dynamicRef": "#meta" } },
          "not": { "$dynamicRef": "#meta" }
        }
      }
      JSON
      )

      UNEVALUATED = JSONHash.from_json(<<-JSON
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://json-schema.org/draft/2020-12/meta/unevaluated",
        "$dynamicAnchor": "meta",
        "title": "Unevaluated applicator vocabulary meta-schema",
        "type": ["object", "boolean"],
        "properties": {
          "unevaluatedItems": { "$dynamicRef": "#meta" },
          "unevaluatedProperties": { "$dynamicRef": "#meta" }
        }
      }
      JSON
      )

      VALIDATION = JSONHash.from_json(<<-JSON
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://json-schema.org/draft/2020-12/meta/validation",
        "$dynamicAnchor": "meta",
        "title": "Validation vocabulary meta-schema",
        "type": ["object", "boolean"],
        "properties": {
          "type": {
            "anyOf": [
              { "enum": ["array", "boolean", "integer", "null", "number", "object", "string"] },
              { "type": "array", "items": { "enum": ["array", "boolean", "integer", "null", "number", "object", "string"] }, "minItems": 1, "uniqueItems": true }
            ]
          },
          "const": true,
          "enum": { "type": "array", "items": true },
          "multipleOf": { "type": "number", "exclusiveMinimum": 0 },
          "maximum": { "type": "number" },
          "exclusiveMaximum": { "type": "number" },
          "minimum": { "type": "number" },
          "exclusiveMinimum": { "type": "number" },
          "maxLength": { "type": "integer", "minimum": 0 },
          "minLength": { "type": "integer", "minimum": 0, "default": 0 },
          "pattern": { "type": "string", "format": "regex" },
          "maxItems": { "type": "integer", "minimum": 0 },
          "minItems": { "type": "integer", "minimum": 0, "default": 0 },
          "uniqueItems": { "type": "boolean", "default": false },
          "maxContains": { "type": "integer", "minimum": 0 },
          "minContains": { "type": "integer", "minimum": 0, "default": 1 },
          "maxProperties": { "type": "integer", "minimum": 0 },
          "minProperties": { "type": "integer", "minimum": 0, "default": 0 },
          "required": { "type": "array", "items": { "type": "string" }, "uniqueItems": true, "default": [] },
          "dependentRequired": { "type": "object", "additionalProperties": { "type": "array", "items": { "type": "string" }, "uniqueItems": true } }
        },
        "$defs": {
          "nonNegativeInteger": { "type": "integer", "minimum": 0 },
          "nonNegativeIntegerDefault0": { "type": "integer", "minimum": 0, "default": 0 },
          "simpleTypes": { "enum": ["array", "boolean", "integer", "null", "number", "object", "string"] },
          "stringArray": { "type": "array", "items": { "type": "string" }, "uniqueItems": true, "default": [] }
        }
      }
      JSON
      )

      META_DATA_SCHEMA = JSONHash.from_json(<<-JSON
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://json-schema.org/draft/2020-12/meta/meta-data",
        "$dynamicAnchor": "meta",
        "title": "Meta-data vocabulary meta-schema",
        "type": ["object", "boolean"],
        "properties": {
          "title": { "type": "string" },
          "description": { "type": "string" },
          "default": true,
          "deprecated": { "type": "boolean", "default": false },
          "readOnly": { "type": "boolean", "default": false },
          "writeOnly": { "type": "boolean", "default": false },
          "examples": { "type": "array", "items": true }
        }
      }
      JSON
      )

      FORMAT_ANNOTATION_SCHEMA = JSONHash.from_json(<<-JSON
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://json-schema.org/draft/2020-12/meta/format-annotation",
        "$dynamicAnchor": "meta",
        "title": "Format vocabulary meta-schema for annotation results",
        "type": ["object", "boolean"],
        "properties": {
          "format": { "type": "string" }
        }
      }
      JSON
      )

      FORMAT_ASSERTION_SCHEMA = JSONHash.from_json(<<-JSON
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://json-schema.org/draft/2020-12/meta/format-assertion",
        "$dynamicAnchor": "meta",
        "title": "Format vocabulary meta-schema for assertion results",
        "type": ["object", "boolean"],
        "properties": {
          "format": { "type": "string" }
        }
      }
      JSON
      )

      CONTENT_SCHEMA = JSONHash.from_json(<<-JSON
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://json-schema.org/draft/2020-12/meta/content",
        "$dynamicAnchor": "meta",
        "title": "Content vocabulary meta-schema",
        "type": ["object", "boolean"],
        "properties": {
          "contentEncoding": { "type": "string" },
          "contentMediaType": { "type": "string" },
          "contentSchema": { "$dynamicRef": "#meta" }
        }
      }
      JSON
      )

      SCHEMAS = {
        URI.parse("https://json-schema.org/draft/2020-12/meta/core")              => CORE,
        URI.parse("https://json-schema.org/draft/2020-12/meta/applicator")        => APPLICATOR,
        URI.parse("https://json-schema.org/draft/2020-12/meta/unevaluated")       => UNEVALUATED,
        URI.parse("https://json-schema.org/draft/2020-12/meta/validation")        => VALIDATION,
        URI.parse("https://json-schema.org/draft/2020-12/meta/meta-data")         => META_DATA_SCHEMA,
        URI.parse("https://json-schema.org/draft/2020-12/meta/format-annotation") => FORMAT_ANNOTATION_SCHEMA,
        URI.parse("https://json-schema.org/draft/2020-12/meta/format-assertion")  => FORMAT_ASSERTION_SCHEMA,
        URI.parse("https://json-schema.org/draft/2020-12/meta/content")           => CONTENT_SCHEMA,
      } of URI => JSONHash

      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        SCHEMAS[uri]?
      }
    end
  end
end
