require "./spec_helper"

# Helper to get errors array from validation result
def get_errors(result : Hash(String, JSON::Any)) : Array(Hash(String, JSON::Any))
  if errors = result["errors"]?
    errors.as_a.map { |e| e.as_h.transform_values { |v| v } }
  else
    [] of Hash(String, JSON::Any)
  end
end

describe "Output Format" do
  describe "flag format" do
    it "returns only valid: true/false" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string"})).as_h)

      result = schema.validate(JSON::Any.new("hello"), output_format: "flag")
      result["valid"].as_bool.should be_true
      result.keys.should eq(["valid"])

      result = schema.validate(JSON::Any.new(42_i64), output_format: "flag")
      result["valid"].as_bool.should be_false
      result.keys.should eq(["valid"])
    end
  end

  describe "basic format" do
    it "returns flat list of errors" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "integer"}
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"name": 123, "age": "thirty"})), output_format: "basic")
      result["valid"].as_bool.should be_false
      result["errors"]?.should_not be_nil
      errors = result["errors"].as_a
      errors.size.should be >= 2
    end

    it "includes keywordLocation and instanceLocation" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string"})).as_h)
      result = schema.validate(JSON::Any.new(42_i64), output_format: "basic")

      errors = result["errors"].as_a
      errors.size.should be >= 1
      errors.first["keywordLocation"]?.should_not be_nil
      errors.first["instanceLocation"]?.should_not be_nil
    end
  end

  describe "detailed format" do
    it "returns hierarchical errors with single path" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"name": 123})), output_format: "detailed")
      result["valid"].as_bool.should be_false
    end
  end

  describe "verbose format" do
    it "returns full validation tree" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"name": 123})), output_format: "verbose")
      result["valid"].as_bool.should be_false
    end
  end

  describe "classic format" do
    it "returns Ruby-compatible error format" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"name": 123})), output_format: "classic")
      result["valid"].as_bool.should be_false
      result["errors"]?.should_not be_nil

      errors = get_errors(result)
      errors.size.should eq(1)

      error = errors.first
      error["data"]?.should_not be_nil
      error["data_pointer"]?.should_not be_nil
      error["schema"]?.should_not be_nil
      error["schema_pointer"]?.should_not be_nil
      error["type"]?.should_not be_nil
      error["error"]?.should_not be_nil
    end

    it "includes data_pointer with JSON pointer format" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"name": 123})), output_format: "classic")
      errors = get_errors(result)
      errors.first["data_pointer"].as_s.should eq("/name")
    end

    it "includes type matching the keyword" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string"})).as_h)
      result = schema.validate(JSON::Any.new(42_i64), output_format: "classic")
      errors = get_errors(result)
      errors.first["type"].as_s.should eq("string")
    end

    it "includes error message" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string"})).as_h)
      result = schema.validate(JSON::Any.new(42_i64), output_format: "classic")
      errors = get_errors(result)
      errors.first["error"].as_s.should_not be_empty
    end
  end

  describe "error details" do
    it "includes missing_keys for required errors" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "required": ["name", "age"]
      })).as_h)

      result = schema.validate(JSON.parse(%q({"name": "John"})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should eq(1)
      errors.first["type"].as_s.should eq("required")
      details = errors.first["details"]?.try(&.as_h)
      details.should_not be_nil
      if d = details
        d["missing_keys"]?.should_not be_nil
      end
    end
  end

  describe "specification examples (polygon schema)" do
    # This is based on the JSON Schema specification output format examples
    it "validates polygon schema with flag format" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "$id": "https://example.com/polygon",
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$defs": {
          "point": {
            "type": "object",
            "properties": {
              "x": {"type": "number"},
              "y": {"type": "number"}
            },
            "additionalProperties": false,
            "required": ["x", "y"]
          }
        },
        "type": "array",
        "items": {"$ref": "#/$defs/point"},
        "minItems": 3
      })).as_h)

      # Valid polygon
      valid_polygon = JSON.parse(%q([
        {"x": 2.5, "y": 1.3},
        {"x": 1, "y": 4.5},
        {"x": 3.2, "y": 2.1}
      ]))
      result = schema.validate(valid_polygon, output_format: "flag")
      result["valid"].as_bool.should be_true

      # Invalid polygon (missing y, extra z, only 2 points)
      invalid_polygon = JSON.parse(%q([
        {"x": 2.5, "y": 1.3},
        {"x": 1, "z": 6.7}
      ]))
      result = schema.validate(invalid_polygon, output_format: "flag")
      result["valid"].as_bool.should be_false
      result.keys.size.should eq(1)
    end

    it "validates polygon schema with basic format" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "$id": "https://example.com/polygon",
        "$defs": {
          "point": {
            "type": "object",
            "properties": {
              "x": {"type": "number"},
              "y": {"type": "number"}
            },
            "additionalProperties": false,
            "required": ["x", "y"]
          }
        },
        "type": "array",
        "items": {"$ref": "#/$defs/point"},
        "minItems": 3
      })).as_h)

      # Invalid polygon
      invalid_polygon = JSON.parse(%q([
        {"x": 2.5, "y": 1.3},
        {"x": 1, "z": 6.7}
      ]))
      result = schema.validate(invalid_polygon, output_format: "basic")
      result["valid"].as_bool.should be_false
      result["errors"]?.should_not be_nil

      errors = result["errors"].as_a
      # Should have errors for:
      # - minItems violation
      # - required y missing
      # - additionalProperties z
      errors.size.should be >= 3

      # Verify error structure
      errors.each do |error|
        error = error.as_h
        error["keywordLocation"]?.should_not be_nil
        error["instanceLocation"]?.should_not be_nil
      end
    end

    it "validates polygon schema with detailed format" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "$id": "https://example.com/polygon",
        "$defs": {
          "point": {
            "type": "object",
            "properties": {
              "x": {"type": "number"},
              "y": {"type": "number"}
            },
            "additionalProperties": false,
            "required": ["x", "y"]
          }
        },
        "type": "array",
        "items": {"$ref": "#/$defs/point"},
        "minItems": 3
      })).as_h)

      # Invalid polygon
      invalid_polygon = JSON.parse(%q([
        {"x": 2.5, "y": 1.3},
        {"x": 1, "z": 6.7}
      ]))
      result = schema.validate(invalid_polygon, output_format: "detailed")
      result["valid"].as_bool.should be_false
    end
  end
end
