require "./spec_helper"

describe "OpenAPI3 Draft202012 Meta Schemas Usage" do
  describe "actual usage during validation" do
    it "resolves Draft202012 meta schemas when validating with OpenAPI dialect" do
      # This test verifies that the Draft202012 meta schemas are actually used
      # during OpenAPI schema validation. The OpenAPI 3.1 dialect references
      # https://json-schema.org/draft/2020-12/schema which in turn references
      # individual vocabulary meta-schemas like meta/core, meta/applicator, etc.

      # Create a simple schema using the OpenAPI 3.1 dialect
      simple_schema = {
        "type"       => JSON::Any.new("object"),
        "properties" => JSON::Any.new({
          "name" => JSON::Any.new({
            "type" => JSON::Any.new("string"),
          }),
        }),
      } of String => JSON::Any

      # This should trigger resolution of Draft202012 meta schemas
      # when the OpenAPI dialect is used as the meta-schema
      schema = JsonSchemer.schema(
        simple_schema,
        meta_schema: JsonSchemer.openapi31
      )

      # Validation should work without errors
      valid_data = JSON.parse(%q({"name": "test"}))
      result = schema.valid?(valid_data)
      result.should be_true
    end

    it "uses Draft202012 meta schemas via SCHEMAS_RESOLVER for $ref resolution" do
      # Test that the SCHEMAS_RESOLVER can resolve Draft202012 meta schema URIs
      # These are used when the OpenAPI dialect schema references them

      resolver = JsonSchemer::OpenAPI3::SCHEMAS_RESOLVER

      # These URIs are referenced by the Draft202012.SCHEMA (which is referenced by OpenAPI dialect)
      meta_schema_uris = [
        "https://json-schema.org/draft/2020-12/meta/core",
        "https://json-schema.org/draft/2020-12/meta/applicator",
        "https://json-schema.org/draft/2020-12/meta/validation",
      ]

      meta_schema_uris.each do |uri_str|
        uri = URI.parse(uri_str)
        resolved = resolver.call(uri)

        resolved.should_not be_nil,
          "SCHEMAS_RESOLVER should resolve #{uri_str} for OpenAPI $ref resolution"

        # Verify it's a valid JSON schema with expected structure
        resolved.not_nil!.has_key?("$id").should be_true
        resolved.not_nil!.has_key?("$schema").should be_true
      end
    end

    it "validates OpenAPI document and extracts component schemas" do
      # This test creates an OpenAPI document with a schema that uses
      # JSON Schema Draft 2020-12 keywords

      document = JSON.parse(%q({
        "openapi": "3.2.0",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {},
        "components": {
          "schemas": {
            "TestSchema": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "integer"
                },
                "name": {
                  "type": "string"
                }
              },
              "required": ["id", "name"]
            }
          }
        }
      })).as_h

      # Get the OpenAPI handler
      openapi = JsonSchemer.openapi(document)

      # Get the TestSchema and validate data against it
      test_schema = openapi.schema("TestSchema")

      # Valid data
      valid = JSON.parse(%q({
        "id": 42,
        "name": "Test Name"
      }))
      test_schema.valid?(valid).should be_true

      # Invalid: missing required field
      invalid = JSON.parse(%q({
        "id": 42
      }))
      test_schema.valid?(invalid).should be_false
    end

    it "validates OpenAPI document with invalid schema keywords" do
      # Test various invalid schema keyword values that should be caught by Draft 2020-12 meta-schemas
      invalid_schemas = [
        %q({"$defs": "invalid"}),                       # Core
        %q({"properties": "invalid"}),                  # Applicator
        %q({"format": {}}),                             # Format
        %q({"readOnly": "bad"}),                        # Metadata
        %q({"minimum": "not a number"}),                # Validation
        %q({"required": true}),                         # Validation
        %q({"properties": ["not", "a", "hash"]}),       # Applicator
        %q({"multipleOf": "not a number"}),             # Validation
        %q({"pattern": 123}),                           # Validation
        %q({"prefixItems": {"not": "an array"}}),       # Applicator
        %q({"uniqueItems": "not a boolean"}),           # Validation
        %q({"dependentSchemas": ["not", "a", "hash"]}), # Applicator
      ]

      invalid_schemas.each do |schema_json|
        document_json = %Q({
          "openapi": "3.2.0",
          "info": {
            "title": "Invalid Schema Test",
            "version": "1.0.0"
          },
          "paths": {},
          "components": {
            "schemas": {
              "InvalidSchema": #{schema_json}
            }
          }
        })

        json_doc = JSON.parse(document_json).as_h

        openapi = JsonSchemer.openapi(json_doc)
        result = openapi.validate
        error_message = result["errors"].as_a.last.as_h["error"].as_s
        error_message.should match(/value at \`\/components\/schemas\/InvalidSchema\/.*\` is not .*/)
        result["valid"].as_bool.should be_false, "OpenAPI document should be invalid with schema: #{schema_json}"
      end
    end

    it "validates OpenAPI document using unevaluatedProperties with invalid value" do
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": { "title": "Test", "version": "1.0.0" },
        "paths": {},
        "components": {
          "schemas": {
            "Invalid": {
              "type": "object",
              "unevaluatedProperties": "not-a-boolean-or-schema"
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_false
    end

    it "validates OpenAPI document using contains with invalid minContains" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
        "info": { "title": "Test", "version": "1.0.0" },
        "paths": {},
        "components": {
          "schemas": {
            "Invalid": {
              "type": "array",
              "contains": { "type": "string" },
              "minContains": "not-a-number"
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_false
    end

    it "validates complex nested schemas with invalid values" do
      # Test that validation works deep inside the OpenAPI document
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": { "title": "Test", "version": "1.0.0" },
        "paths": {
          "/test": {
            "get": {
              "responses": {
                "200": {
                  "description": "OK",
                  "content": {
                    "application/json": {
                      "schema": {
                        "type": "object",
                        "properties": {
                          "data": {
                            "type": "array",
                            "items": {
                              "type": "string",
                              "maxLength": "invalid-length"
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_false
    end

    it "validates instances against Draft 2020-12 keywords in OpenAPI document" do
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": { "title": "Test", "version": "1.0.0" },
        "paths": {},
        "components": {
          "schemas": {
            "Tuple": {
              "type": "array",
              "prefixItems": [
                { "type": "string" },
                { "type": "number" }
              ],
              "items": false
            },
            "StrictObject": {
              "type": "object",
              "properties": {
                "name": { "type": "string" }
              },
              "unevaluatedProperties": false
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_true

      tuple_schema = openapi.schema("Tuple")
      tuple_schema.valid?(JSON.parse(%q(["hello", 42]))).should be_true
      tuple_schema.valid?(JSON.parse(%q(["hello", "world"]))).should be_false     # Wrong type for 2nd item
      tuple_schema.valid?(JSON.parse(%q(["hello", 42, "extra"]))).should be_false # extra item not allowed by items: false

      strict_schema = openapi.schema("StrictObject")
      strict_schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true
      strict_schema.valid?(JSON.parse(%q({"name": "John", "age": 30}))).should be_false # age is unevaluated
    end

    it "validates schema using allOf which requires applicator meta-schema" do
      # The allOf keyword is defined in the applicator meta-schema
      # This test ensures the applicator meta-schema is properly resolved

      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {},
        "components": {
          "schemas": {
            "Combined": {
              "allOf": [
                {
                  "type": "object",
                  "properties": {
                    "name": { "type": "string" }
                  },
                  "required": ["name"]
                },
                {
                  "type": "object",
                  "properties": {
                    "age": { "type": "integer" }
                  }
                }
              ]
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      combined_schema = openapi.schema("Combined")

      # Valid: satisfies both schemas in allOf
      valid = JSON.parse(%q({
        "name": "John",
        "age": 30
      }))
      combined_schema.valid?(valid).should be_true

      # Invalid: missing required field from first schema
      invalid = JSON.parse(%q({
        "age": 30
      }))
      combined_schema.valid?(invalid).should be_false
    end

    it "demonstrates that Draft202012 meta schemas are available for $ref resolution" do
      # This test demonstrates that without the Draft202012 meta schemas,
      # validation would fail because the OpenAPI dialect references them.
      #
      # The OpenAPI 3.1 dialect schema has:
      #   "allOf": [
      #     { "$ref": "https://json-schema.org/draft/2020-12/schema" },
      #     { "$ref": "https://spec.openapis.org/oas/3.1/meta/2024-11-10" }
      #   ]
      #
      # The draft/2020-12/schema has $refs to individual vocabulary schemas:
      #   "allOf": [
      #     { "$ref": "meta/core" },
      #     { "$ref": "meta/applicator" },
      #     ...
      #   ]

      # Verify all required Draft202012 meta schemas are present
      required_meta_schemas = [
        "https://json-schema.org/draft/2020-12/meta/core",
        "https://json-schema.org/draft/2020-12/meta/applicator",
        "https://json-schema.org/draft/2020-12/meta/unevaluated",
        "https://json-schema.org/draft/2020-12/meta/validation",
        "https://json-schema.org/draft/2020-12/meta/meta-data",
        "https://json-schema.org/draft/2020-12/meta/format-annotation",
        "https://json-schema.org/draft/2020-12/meta/format-assertion",
        "https://json-schema.org/draft/2020-12/meta/content",
      ]

      resolver = JsonSchemer::OpenAPI3::SCHEMAS_RESOLVER

      required_meta_schemas.each do |uri_str|
        uri = URI.parse(uri_str)
        schema_data = resolver.call(uri)

        schema_data.should_not be_nil,
          "Draft202012 meta schema #{uri_str} should be resolvable via SCHEMAS_RESOLVER"

        # Verify the schema data contains expected JSON Schema keywords
        schema = schema_data.not_nil!
        schema.has_key?("$id").should be_true
        schema.has_key?("$schema").should be_true
        schema.has_key?("$dynamicAnchor").should be_true
      end
    end
  end
end
