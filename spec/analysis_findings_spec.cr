require "./spec_helper"

# Tests verifying findings from src_analysis_report.md

describe "Analysis Report Findings" do
  describe "B-1: OpenAPI keywords parameter type mismatch" do
    it "accepts custom keywords with Keyword parameter in OpenAPI constructor" do
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {},
        "components": {
          "schemas": {
            "User": {
              "type": "object",
              "x-custom-check": true,
              "properties": {
                "name": {"type": "string"}
              }
            }
          }
        }
      })).as_h

      custom_called = false
      keywords = {
        "x-custom-check" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String, keyword : JsonSchemer::Keyword) {
          custom_called = true
          (true).as(Bool | Array(String))
        },
      }

      openapi = JsonSchemer.openapi(document, keywords: keywords)
      user_schema = openapi.schema("User")
      user_schema.valid?(JSON.parse(%q({"name": "test"})))
      custom_called.should be_true
    end
  end

  describe "B-2: EcmaRegexp.valid? calls crystal_equivalent twice" do
    it "validates a valid ECMA pattern" do
      JsonSchemer::EcmaRegexp.valid?("^[a-z]+$").should be_true
    end

    it "rejects an invalid ECMA pattern" do
      JsonSchemer::EcmaRegexp.valid?("(unclosed").should be_false
    end

    it "handles complex patterns without redundant computation" do
      # This test verifies the method works correctly - the fix is about performance
      JsonSchemer::EcmaRegexp.valid?("(?:foo|bar)+\\d{2,5}").should be_true
    end
  end

  describe "Q-3: Redundant nil UUID check" do
    it "validates the nil UUID via regex" do
      # The nil UUID already matches UUID_REGEX, so the || branch is dead code
      JsonSchemer::Format::UUID_REGEX.matches?("00000000-0000-0000-0000-000000000000").should be_true
    end

    it "validates the nil UUID via valid_uuid?" do
      JsonSchemer::Format.valid_uuid?("00000000-0000-0000-0000-000000000000").should be_true
    end

    it "validates normal UUIDs" do
      JsonSchemer::Format.valid_uuid?("550e8400-e29b-41d4-a716-446655440000").should be_true
    end

    it "rejects invalid UUIDs" do
      JsonSchemer::Format.valid_uuid?("not-a-uuid").should be_false
    end
  end

  describe "S-5: Integer overflow in parse_int_limit" do
    it "handles normal integer maxLength" do
      schema = JsonSchemer.schema(%q({"type": "string", "maxLength": 10}))
      schema.valid?(JSON::Any.new("short")).should be_true
      schema.valid?(JSON::Any.new("this string is way too long")).should be_false
    end

    it "raises on float maxLength exceeding Int64 range" do
      # 1e19 > Int64::MAX (9.2e18), should raise InvalidSchema
      expect_raises(JsonSchemer::InvalidSchema) do
        JsonSchemer.schema(%q({"type": "string", "maxLength": 1e19}))
      end
    end

    it "raises on negative float exceeding Int64 range" do
      expect_raises(JsonSchemer::InvalidSchema) do
        JsonSchemer.schema(%q({"type": "string", "maxLength": -1e19}))
      end
    end
  end

  describe "S-1: NET_HTTP_REF_RESOLVER timeout" do
    # This is a code review finding - we verify the resolver exists and is a proc
    # Actual timeout behavior requires network mocking
    it "NET_HTTP_REF_RESOLVER is defined" do
      JsonSchemer::NET_HTTP_REF_RESOLVER.should_not be_nil
    end
  end

  describe "P-3: Default keyword clones value on every access" do
    it "inserts default values correctly" do
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "properties": {
          "status": {"type": "string", "default": "active"}
        }
      }), insert_property_defaults: true)

      data = JSON.parse(%q({}))
      schema.validate(data)
      data.as_h["status"]?.try(&.as_s).should eq("active")
    end

    it "does not allow mutation of schema default through validation" do
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "properties": {
          "tags": {"type": "array", "default": ["a", "b"]}
        }
      }), insert_property_defaults: true)

      # Validate first instance
      data1 = JSON.parse(%q({}))
      schema.validate(data1)
      tags1 = data1.as_h["tags"]?.try(&.as_a)
      tags1.should_not be_nil

      # Validate second instance - should get clean default, not mutated copy
      data2 = JSON.parse(%q({}))
      schema.validate(data2)
      tags2 = data2.as_h["tags"]?.try(&.as_a)
      tags2.should_not be_nil
      tags2.try(&.size).should eq(2)
    end
  end
end
