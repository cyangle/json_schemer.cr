require "./spec_helper"

describe "OpenAPI3 Draft202012 Meta Schemas" do
  describe "OpenAPI3.schemas" do
    it "includes Draft202012 meta schemas for $ref resolution" do
      # The OpenAPI 3.1/3.2 dialect schemas reference JSON Schema Draft 2020-12 vocabulary schemas
      # via $ref. These meta-schemas must be available for proper validation.
      #
      # For example, the OpenAPI 3.1 dialect schema has:
      #   "allOf": [
      #       { "$ref": "https://json-schema.org/draft/2020-12/schema" },
      #       { "$ref": "https://spec.openapis.org/oas/3.1/meta/base" }
      #   ]
      #
      # The draft/2020-12/schema references individual vocabulary meta-schemas.

      expected_uris = [
        "https://json-schema.org/draft/2020-12/meta/core",
        "https://json-schema.org/draft/2020-12/meta/applicator",
        "https://json-schema.org/draft/2020-12/meta/unevaluated",
        "https://json-schema.org/draft/2020-12/meta/validation",
        "https://json-schema.org/draft/2020-12/meta/meta-data",
        "https://json-schema.org/draft/2020-12/meta/format-annotation",
        "https://json-schema.org/draft/2020-12/meta/format-assertion",
        "https://json-schema.org/draft/2020-12/meta/content",
      ]

      expected_uris.each do |uri|
        uri_obj = URI.parse(uri)
        JsonSchemer::OpenAPI3.resolve_schema(uri_obj).should_not be_nil,
          "Expected OpenAPI3.schemas to contain #{uri} for proper $ref resolution"
      end
    end

    it "can resolve Draft202012 meta schemas via SCHEMAS_RESOLVER" do
      # The SCHEMAS_RESOLVER is used when validating OpenAPI documents
      # It must be able to resolve JSON Schema Draft 2020-12 vocabulary schemas

      resolver = JsonSchemer::OpenAPI3::SCHEMAS_RESOLVER

      core_uri = URI.parse("https://json-schema.org/draft/2020-12/meta/core")
      resolved = resolver.call(core_uri)

      resolved.should_not be_nil
      resolved.not_nil!["$id"].should eq("https://json-schema.org/draft/2020-12/meta/core")
    end
  end
end
