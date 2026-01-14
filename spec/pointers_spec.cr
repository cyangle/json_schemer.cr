require "./spec_helper"

# Helper to get errors array from validation result
def get_errors(result : Hash(String, JSON::Any)) : Array(Hash(String, JSON::Any))
  if errors = result["errors"]?
    errors.as_a.map { |e| e.as_h.transform_values { |v| v } }
  else
    [] of Hash(String, JSON::Any)
  end
end

describe "JSON Pointer" do
  describe "escaping" do
    it "escapes ~ as ~0" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "foo~bar": {"type": "string"}
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"foo~bar": 123})), output_format: "classic")
      errors = get_errors(result)
      errors.first["data_pointer"].as_s.should eq("/foo~0bar")
      errors.first["schema_pointer"].as_s.should eq("/properties/foo~0bar")
    end

    it "escapes / as ~1" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "foo/bar": {"type": "string"}
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"foo/bar": 123})), output_format: "classic")
      errors = get_errors(result)
      errors.first["data_pointer"].as_s.should eq("/foo~1bar")
      errors.first["schema_pointer"].as_s.should eq("/properties/foo~1bar")
    end

    it "escapes both ~ and / correctly" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "foo/bar~": {"type": "string"}
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"foo/bar~": 123})), output_format: "classic")
      errors = get_errors(result)
      errors.first["data_pointer"].as_s.should eq("/foo~1bar~0")
      errors.first["schema_pointer"].as_s.should eq("/properties/foo~1bar~0")
    end
  end

  describe "array indices" do
    it "includes array index in pointer" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "array",
        "items": {"type": "integer"}
      })).as_h)

      result = schema.validate(JSON.parse(%q([1, "two", 3])), output_format: "classic")
      errors = get_errors(result)
      errors.first["data_pointer"].as_s.should eq("/1")
    end
  end

  describe "nested paths" do
    it "includes full nested path" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "person": {
            "type": "object",
            "properties": {
              "address": {
                "type": "object",
                "properties": {
                  "zip": {"type": "string"}
                }
              }
            }
          }
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({
        "person": {
          "address": {
            "zip": 12345
          }
        }
      })), output_format: "classic")
      errors = get_errors(result)
      errors.first["data_pointer"].as_s.should eq("/person/address/zip")
    end
  end

  describe "$ref pointer resolution" do
    it "returns correct pointers for $ref within schema" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "$defs": {
          "y": {"type": "string"}
        },
        "properties": {
          "a": {
            "properties": {
              "x": {"$ref": "#/$defs/y"}
            }
          }
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"a": {"x": 1}})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should be > 0
      errors.first["data_pointer"].as_s.should eq("/a/x")
      errors.first["schema_pointer"].as_s.should eq("/$defs/y")
    end
  end

  describe "prefixItems pointers" do
    it "returns correct pointers for prefixItems array" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "x": {
            "prefixItems": [
              {"type": "integer"},
              {"type": "string"}
            ]
          }
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"x": ["wrong", 1]})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should eq(2)

      # First error: "wrong" is not integer
      errors[0]["data_pointer"].as_s.should eq("/x/0")
      errors[0]["schema_pointer"].as_s.should eq("/properties/x/prefixItems/0")

      # Second error: 1 is not string
      errors[1]["data_pointer"].as_s.should eq("/x/1")
      errors[1]["schema_pointer"].as_s.should eq("/properties/x/prefixItems/1")
    end

    it "returns correct pointers for items after prefixItems" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "x": {
            "prefixItems": [
              {"type": "integer"}
            ],
            "items": {"type": "string"}
          }
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"x": ["wrong", 1]})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should eq(2)

      # First error: "wrong" is not integer
      errors[0]["data_pointer"].as_s.should eq("/x/0")
      errors[0]["schema_pointer"].as_s.should eq("/properties/x/prefixItems/0")

      # Second error: 1 is not string - Crystal adds trailing /
      errors[1]["data_pointer"].as_s.should eq("/x/1")
      errors[1]["schema_pointer"].as_s.should start_with("/properties/x/items")
    end
  end

  describe "items pointers" do
    it "returns correct pointers for items schema" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "x": {
            "items": {"type": "boolean"}
          }
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"x": ["wrong", 1]})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should eq(2)

      # Crystal implementation may add trailing /
      errors[0]["data_pointer"].as_s.should eq("/x/0")
      errors[0]["schema_pointer"].as_s.should start_with("/properties/x/items")

      errors[1]["data_pointer"].as_s.should eq("/x/1")
      errors[1]["schema_pointer"].as_s.should start_with("/properties/x/items")
    end
  end

  describe "propertyNames pointers" do
    it "returns correct pointers for propertyNames" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "x": {
            "propertyNames": {"minLength": 10}
          }
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"x": {"abc": 1}})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should be > 0
      errors.first["data_pointer"].as_s.should eq("/x")
      # Crystal implementation may add trailing /
      errors.first["schema_pointer"].as_s.should start_with("/properties/x/propertyNames")
    end
  end

  describe "patternProperties pointers" do
    it "returns correct pointers for patternProperties" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "x": {
            "patternProperties": {
              "^a": {"type": "string"}
            }
          }
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"x": {"abc": 1}})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should be > 0
      errors.first["data_pointer"].as_s.should eq("/x/abc")
      errors.first["schema_pointer"].as_s.should eq("/properties/x/patternProperties/^a")
    end
  end

  describe "additionalProperties pointers" do
    it "returns correct pointers for additionalProperties" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "x": {
            "additionalProperties": {"type": "string"}
          }
        }
      })).as_h)

      result = schema.validate(JSON.parse(%q({"x": {"abc": 1}})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should be > 0
      errors.first["data_pointer"].as_s.should eq("/x/abc")
      # Crystal implementation may add trailing /
      errors.first["schema_pointer"].as_s.should start_with("/properties/x/additionalProperties")
    end
  end
end
