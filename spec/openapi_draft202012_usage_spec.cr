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
        "openapi": "3.1.0",
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
