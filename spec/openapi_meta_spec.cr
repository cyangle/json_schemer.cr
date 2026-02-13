require "./spec_helper"

describe "OpenAPI Meta Schema Loading" do
  it "fully loads OpenAPI 3.1 entrypoint schema with all Draft 2020-12 vocabularies" do
    document_schema = JsonSchemer.openapi31_document

    # Check if core keywords are present
    document_schema.keywords.has_key?("$schema").should be_true
    document_schema.keywords.has_key?("$id").should be_true
    document_schema.keywords.has_key?("$ref").should be_true

    # Check unevaluated keywords (Draft 2020-12 specific)
    document_schema.keywords.has_key?("unevaluatedProperties").should be_true
    document_schema.keywords.has_key?("unevaluatedItems").should be_true
  end

  it "fully loads OpenAPI 3.2 entrypoint schema with all Draft 2020-12 vocabularies" do
    document_schema = JsonSchemer.openapi32_document

    document_schema.keywords.has_key?("$id").should be_true
    document_schema.keywords.has_key?("unevaluatedProperties").should be_true
  end

  it "fully loads OpenAPI 3.2 dialect schema with all Draft 2020-12 vocabularies" do
    dialect_uri = URI.parse("https://spec.openapis.org/oas/3.2/dialect/2025-09-17")
    dialect_schema_hash = JsonSchemer::OpenAPI3.schemas[dialect_uri]?
    dialect_schema_hash.should_not be_nil

    dialect_schema = JsonSchemer.schema(
      dialect_schema_hash.not_nil!,
      ref_resolver: JsonSchemer::OpenAPI3::SCHEMAS_RESOLVER
    )

    # The dialect schema defines the vocabulary for OpenAPI component schemas
    dialect_schema.keywords.has_key?("$id").should be_true
    dialect_schema.keywords.has_key?("unevaluatedProperties").should be_true
    # It also has OpenAPI base keywords
    dialect_schema.keywords.has_key?("discriminator").should be_true
  end

  it "ensures the OpenAPI 3.2 meta-schema registers itself via $id" do
    meta_uri = URI.parse("https://spec.openapis.org/oas/3.2/meta/2025-09-17")
    dialect_uri = URI.parse("https://spec.openapis.org/oas/3.2/dialect/2025-09-17")

    dialect_schema = JsonSchemer.schema(
      JsonSchemer::OpenAPI3.schemas[dialect_uri].not_nil!,
      ref_resolver: JsonSchemer::OpenAPI3::SCHEMAS_RESOLVER
    )

    # This triggers $ref resolution which loads the meta-schema
    meta_schema = dialect_schema.ref("https://spec.openapis.org/oas/3.2/meta/2025-09-17")

    # The meta-schema should have recognized its own $id during parsing
    meta_schema.parsed.has_key?("$id").should be_true

    # It should be registered in its own resources under its canonical URI
    meta_schema.resources[:lexical].key?(meta_uri).should be_true
  end

  it "validates an OpenAPI 3.2 document using unevaluatedProperties in components/schemas" do
    document = {
      "openapi" => "3.2.0",
      "info"    => {
        "title"   => "Test API",
        "version" => "1.0.0",
      },
      "paths"      => {} of String => JSON::Any,
      "components" => {
        "schemas" => {
          "User" => {
            "type"       => "object",
            "properties" => {
              "name" => {"type" => "string"},
            },
            "unevaluatedProperties" => false,
          },
        },
      },
    }

    openapi = JsonSchemer.openapi(JSON.parse(document.to_json).as_h)
    openapi.valid?.should be_true

    user_schema = openapi.schema("User")
    user_schema.valid?({"name" => "John"}).should be_true
    user_schema.valid?({"name" => "John", "extra" => 123}).should be_false
  end
end
