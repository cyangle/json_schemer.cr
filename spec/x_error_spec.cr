require "./spec_helper"

describe "x-error" do
  it "overrides default error message with x-error string" do
    schema = JsonSchemer.schema(%q({
      "type": "string",
      "x-error": "custom error message"
    }))

    result = schema.validate(1, output_format: "basic")
    result["error"].as_s.should eq("custom error message")
  end

  it "overrides keyword error message with x-error hash" do
    schema = JsonSchemer.schema(%q({
      "type": "object",
      "properties": {
        "foo": {
          "type": "string",
          "minLength": 5,
          "x-error": {
            "minLength": "too short"
          }
        }
      }
    }))

    data = JSON.parse(%q({"foo": "abc"}))
    result = schema.validate(data, output_format: "classic")

    errors = result["errors"].as_a
    errors.size.should eq(1)
    errors.first["error"].as_s.should eq("too short")
  end

  it "supports variable interpolation" do
    schema = JsonSchemer.schema(%q({
      "type": "object",
      "properties": {
        "age": {
          "type": "integer",
          "minimum": 18,
          "x-error": "Value %{instance} at %{instanceLocation} must be at least %{keywordValue}"
        }
      }
    }))

    data = JSON.parse(%q({"age": 10}))
    result = schema.validate(data, output_format: "basic")

    # 10 is an integer, so inspect might be 10.
    result["errors"].as_a.first["error"].as_s.should eq("Value 10 at /age must be at least 18")
  end

  it "supports special ^ key for schema-level errors" do
    schema = JsonSchemer.schema(%q({
      "type": "string",
      "minLength": 5,
      "x-error": {
        "^": "schema error",
        "minLength": "keyword error"
      }
    }))

    # Trigger schema error (type mismatch)
    # When output_format is basic, the top-level error (if valid=false) is usually from the root schema
    # IF the root schema itself failed.
    # For type mismatch, the root schema fails.
    result = schema.validate(1, output_format: "basic")
    result["error"].as_s.should eq("schema error")

    # Trigger keyword error (minLength)
    # The root schema is valid (it is a string), but minLength keyword fails.
    # In basic output, top level is valid=false, and errors array contains keyword errors.
    result = schema.validate("abc", output_format: "basic")
    result["errors"].as_a.first["error"].as_s.should eq("keyword error")
  end

  it "supports special * key as fallback" do
    schema = JsonSchemer.schema(%q({
      "type": "string",
      "minLength": 5,
      "pattern": "^a",
      "x-error": {
        "minLength": "keyword error",
        "*": "fallback error"
      }
    }))

    # Trigger schema error (type mismatch) - should fallback to * since ^ is missing
    result = schema.validate(1, output_format: "basic")
    result["error"].as_s.should eq("fallback error")

    # Trigger pattern error - should fallback to * since pattern is missing
    result = schema.validate("bbbbbb", output_format: "basic")
    result["errors"].as_a.first["error"].as_s.should eq("fallback error")

    # Trigger minLength error - should use specific message
    result = schema.validate("a", output_format: "basic")
    result["errors"].as_a.first["error"].as_s.should eq("keyword error")
  end
end
