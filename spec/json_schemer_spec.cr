require "./spec_helper"

describe JsonSchemer do
  describe "VERSION" do
    it "has a version number" do
      JsonSchemer::VERSION.should_not be_nil
    end
  end

  describe ".schema" do
    it "creates a schema from a Hash" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("string")} of String => JSON::Any)
      schema.should be_a(JsonSchemer::Schema)
    end

    it "creates a schema from a JSON string" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      schema.should be_a(JsonSchemer::Schema)
    end
  end

  describe "basic validation" do
    it "validates type: string" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("string")} of String => JSON::Any)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(123_i64)).should be_false
    end

    it "validates type: integer" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("integer")} of String => JSON::Any)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new(42.5)).should be_false
      schema.valid?(JSON::Any.new("42")).should be_false
    end

    it "validates type: number" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("number")} of String => JSON::Any)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new(42.5)).should be_true
      schema.valid?(JSON::Any.new("42")).should be_false
    end

    it "validates type: boolean" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("boolean")} of String => JSON::Any)
      schema.valid?(JSON::Any.new(true)).should be_true
      schema.valid?(JSON::Any.new(false)).should be_true
      schema.valid?(JSON::Any.new("true")).should be_false
    end

    it "validates type: null" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("null")} of String => JSON::Any)
      schema.valid?(JSON::Any.new(nil)).should be_true
      schema.valid?(JSON::Any.new("")).should be_false
    end

    it "validates type: array" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("array")} of String => JSON::Any)
      schema.valid?(JSON.parse("[]")).should be_true
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_true
      schema.valid?(JSON.parse("{}")).should be_false
    end

    it "validates type: object" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("object")} of String => JSON::Any)
      schema.valid?(JSON.parse("{}")).should be_true
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
      schema.valid?(JSON.parse("[]")).should be_false
    end

    it "validates multiple types" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": ["string", "integer"]})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new(42.5)).should be_false
    end
  end

  describe "enum validation" do
    it "validates enum values" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": ["red", "green", "blue"]})).as_h)
      schema.valid?(JSON::Any.new("red")).should be_true
      schema.valid?(JSON::Any.new("green")).should be_true
      schema.valid?(JSON::Any.new("yellow")).should be_false
    end

    it "validates enum with mixed types" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": [1, "two", null]})).as_h)
      schema.valid?(JSON::Any.new(1_i64)).should be_true
      schema.valid?(JSON::Any.new("two")).should be_true
      schema.valid?(JSON::Any.new(nil)).should be_true
      schema.valid?(JSON::Any.new(2_i64)).should be_false
    end
  end

  describe "const validation" do
    it "validates const value" do
      schema = JsonSchemer.schema(JSON.parse(%q({"const": "hello"})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("world")).should be_false
    end
  end

  describe "numeric validations" do
    it "validates minimum" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "minimum": 10})).as_h)
      schema.valid?(JSON::Any.new(10_i64)).should be_true
      schema.valid?(JSON::Any.new(15_i64)).should be_true
      schema.valid?(JSON::Any.new(5_i64)).should be_false
    end

    it "validates maximum" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "maximum": 100})).as_h)
      schema.valid?(JSON::Any.new(100_i64)).should be_true
      schema.valid?(JSON::Any.new(50_i64)).should be_true
      schema.valid?(JSON::Any.new(150_i64)).should be_false
    end

    it "validates exclusiveMinimum" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "exclusiveMinimum": 10})).as_h)
      schema.valid?(JSON::Any.new(11_i64)).should be_true
      schema.valid?(JSON::Any.new(10_i64)).should be_false
    end

    it "validates exclusiveMaximum" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "exclusiveMaximum": 100})).as_h)
      schema.valid?(JSON::Any.new(99_i64)).should be_true
      schema.valid?(JSON::Any.new(100_i64)).should be_false
    end

    it "validates multipleOf" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "multipleOf": 5})).as_h)
      schema.valid?(JSON::Any.new(10_i64)).should be_true
      schema.valid?(JSON::Any.new(15_i64)).should be_true
      schema.valid?(JSON::Any.new(7_i64)).should be_false
    end

    it "handles float multipleOf" do
      schema = JsonSchemer.schema(JSON.parse(%q({"multipleOf": 0.01})).as_h)
      schema.valid?(JSON::Any.new(8.61)).should be_true
      schema.valid?(JSON::Any.new(8.666)).should be_false
    end
  end

  describe "string validations" do
    it "validates maxLength" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "maxLength": 5})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("hi")).should be_true
      schema.valid?(JSON::Any.new("hello world")).should be_false
    end

    it "validates minLength" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "minLength": 3})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("hi")).should be_false
    end

    it "validates pattern" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "pattern": "^[a-z]+$"})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("Hello")).should be_false
      schema.valid?(JSON::Any.new("hello123")).should be_false
    end
  end

  describe "array validations" do
    it "validates maxItems" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "maxItems": 3})).as_h)
      schema.valid?(JSON.parse("[1, 2]")).should be_true
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_true
      schema.valid?(JSON.parse("[1, 2, 3, 4]")).should be_false
    end

    it "validates minItems" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "minItems": 2})).as_h)
      schema.valid?(JSON.parse("[1, 2]")).should be_true
      schema.valid?(JSON.parse("[1]")).should be_false
    end

    it "validates uniqueItems" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_true
      schema.valid?(JSON.parse("[1, 2, 2]")).should be_false
    end

    it "validates items schema" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "items": {"type": "integer"}})).as_h)
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_true
      schema.valid?(JSON.parse(%q([1, "two", 3]))).should be_false
    end

    it "validates prefixItems" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "array",
        "prefixItems": [
          {"type": "string"},
          {"type": "integer"}
        ]
      })).as_h)
      schema.valid?(JSON.parse(%q(["hello", 42]))).should be_true
      schema.valid?(JSON.parse(%q([42, "hello"]))).should be_false
    end

    it "validates contains" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "array",
        "contains": {"type": "integer"}
      })).as_h)
      schema.valid?(JSON.parse(%q(["a", 1, "b"]))).should be_true
      schema.valid?(JSON.parse(%q(["a", "b", "c"]))).should be_false
    end
  end

  describe "object validations" do
    it "validates maxProperties" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "object", "maxProperties": 2})).as_h)
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2}))).should be_true
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2, "c": 3}))).should be_false
    end

    it "validates minProperties" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "object", "minProperties": 2})).as_h)
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2}))).should be_true
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_false
    end

    it "validates required" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "required": ["name", "age"]
      })).as_h)
      schema.valid?(JSON.parse(%q({"name": "John", "age": 30}))).should be_true
      schema.valid?(JSON.parse(%q({"name": "John"}))).should be_false
    end

    it "validates properties" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "integer"}
        }
      })).as_h)
      schema.valid?(JSON.parse(%q({"name": "John", "age": 30}))).should be_true
      schema.valid?(JSON.parse(%q({"name": "John", "age": "thirty"}))).should be_false
    end

    it "validates additionalProperties: false" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "name": {"type": "string"}
        },
        "additionalProperties": false
      })).as_h)
      schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true
      schema.valid?(JSON.parse(%q({"name": "John", "age": 30}))).should be_false
    end

    it "validates patternProperties" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "patternProperties": {
          "^x-": {"type": "string"}
        }
      })).as_h)
      schema.valid?(JSON.parse(%q({"x-custom": "value"}))).should be_true
      schema.valid?(JSON.parse(%q({"x-custom": 123}))).should be_false
    end

    it "validates propertyNames" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "propertyNames": {"pattern": "^[a-z]+$"}
      })).as_h)
      schema.valid?(JSON.parse(%q({"foo": 1, "bar": 2}))).should be_true
      schema.valid?(JSON.parse(%q({"Foo": 1}))).should be_false
    end
  end

  describe "combinators" do
    it "validates allOf" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "allOf": [
          {"type": "object"},
          {"required": ["name"]}
        ]
      })).as_h)
      schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true
      schema.valid?(JSON.parse(%q({}))).should be_false
    end

    it "validates anyOf" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "anyOf": [
          {"type": "string"},
          {"type": "integer"}
        ]
      })).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new(true)).should be_false
    end

    it "validates oneOf" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "oneOf": [
          {"type": "integer", "minimum": 0},
          {"type": "integer", "maximum": 0}
        ]
      })).as_h)
      schema.valid?(JSON::Any.new(5_i64)).should be_true
      schema.valid?(JSON::Any.new(-5_i64)).should be_true
      schema.valid?(JSON::Any.new(0_i64)).should be_false # matches both
    end

    it "validates not" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "not": {"type": "string"}
      })).as_h)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new("hello")).should be_false
    end
  end

  describe "conditional validation" do
    it "validates if/then/else" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "if": {"properties": {"type": {"const": "person"}}},
        "then": {"required": ["name"]},
        "else": {"required": ["title"]}
      })).as_h)

      schema.valid?(JSON.parse(%q({"type": "person", "name": "John"}))).should be_true
      schema.valid?(JSON.parse(%q({"type": "book", "title": "Moby Dick"}))).should be_true
      schema.valid?(JSON.parse(%q({"type": "person", "title": "Mr"}))).should be_false
    end
  end

  describe "$ref" do
    it "resolves internal references" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "$defs": {
          "positiveInteger": {
            "type": "integer",
            "minimum": 1
          }
        },
        "type": "object",
        "properties": {
          "count": {"$ref": "#/$defs/positiveInteger"}
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({"count": 5}))).should be_true
      schema.valid?(JSON.parse(%q({"count": 0}))).should be_false
    end
  end

  describe "output formats" do
    it "returns flag format" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("string")} of String => JSON::Any)
      result = schema.validate(JSON::Any.new(42_i64), output_format: "flag")
      result["valid"].as_bool.should be_false
    end

    it "returns basic format with errors" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("string")} of String => JSON::Any)
      result = schema.validate(JSON::Any.new(42_i64), output_format: "basic")
      result["valid"].as_bool.should be_false
      result["errors"]?.should_not be_nil
    end

    it "returns classic format with errors" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("string")} of String => JSON::Any)
      result = schema.validate(JSON::Any.new(42_i64), output_format: "classic")
      result["valid"].as_bool.should be_false
      errors = get_errors(result)
      errors.size.should eq(1)
      errors.first["type"].as_s.should eq("string")
    end
  end

  describe "empty schema" do
    it "accepts any value" do
      schema = JsonSchemer.schema({} of String => JSON::Any)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON.parse("[]")).should be_true
      schema.valid?(JSON.parse("{}")).should be_true
    end
  end

  describe "JSON pointer escaping" do
    it "escapes special characters in data_pointer and schema_pointer" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "properties": {
          "foo/bar~": {
            "type": "string"
          }
        }
      })).as_h)
      result = schema.validate(JSON.parse(%q({"foo/bar~": 1})), output_format: "classic")
      errors = get_errors(result)
      errors.size.should eq(1)
      errors.first["data_pointer"].as_s.should eq("/foo~1bar~0")
      errors.first["schema_pointer"].as_s.should eq("/properties/foo~1bar~0")
    end
  end

  describe "nested error validation" do
    it "returns errors for nested allOf/anyOf/oneOf" do
      schema_hash = JSON.parse(%q({
        "type": "object",
        "required": ["numberOfModules"],
        "properties": {
          "numberOfModules": {
            "allOf": [
              {
                "not": {
                  "type": "integer",
                  "minimum": 38
                }
              },
              {
                "not": {
                  "type": "integer",
                  "maximum": 37,
                  "minimum": 25
                }
              },
              {
                "not": {
                  "type": "integer",
                  "maximum": 24,
                  "minimum": 12
                }
              }
            ],
            "anyOf": [
              { "type": "integer" },
              { "type": "string" }
            ],
            "oneOf": [
              { "type": "integer" },
              { "type": "integer" },
              { "type": "boolean" }
            ]
          }
        }
      })).as_h
      schema = JsonSchemer.schema(schema_hash)

      # Value 32 fails the second "not" check (between 25 and 37)
      result = schema.validate(JSON.parse(%q({"numberOfModules": 32})), output_format: "classic")
      errors = get_errors(result)
      errors.any? { |e| e["type"].as_s == "not" }.should be_true

      # Boolean value fails anyOf (not integer or string)
      result = schema.validate(JSON.parse(%q({"numberOfModules": true})), output_format: "classic")
      errors = get_errors(result)
      errors.any? { |e| e["type"].as_s == "integer" || e["type"].as_s == "string" }.should be_true

      # Value 8 fails oneOf (matches both integer schemas)
      result = schema.validate(JSON.parse(%q({"numberOfModules": 8})), output_format: "classic")
      errors = get_errors(result)
      errors.any? { |e| e["type"].as_s == "oneof" }.should be_true
    end
  end

  describe "unevaluatedItems" do
    it "validates unevaluated array items" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "prefixItems": [
          { "type": "integer" }
        ],
        "unevaluatedItems": false
      })).as_h)

      # Invalid first item
      result = schema.validate(JSON.parse(%q(["invalid"])), output_format: "classic")
      errors = get_errors(result)
      errors.any? { |e| e["schema_pointer"].as_s.includes?("prefixItems") }.should be_true

      # Valid first item, but extra unevaluated item
      result = schema.validate(JSON.parse(%q([1, "unevaluated"])), output_format: "classic")
      errors = get_errors(result)
      errors.any? { |e| e["schema_pointer"].as_s.includes?("unevaluatedItems") }.should be_true

      # Both invalid first item and extra unevaluated
      result = schema.validate(JSON.parse(%q(["invalid", "unevaluated"])), output_format: "classic")
      errors = get_errors(result)
      errors.size.should be >= 2
    end
  end

  describe "unevaluatedProperties" do
    it "validates unevaluated object properties" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "foo": { "type": "integer" }
        },
        "unevaluatedProperties": false
      })).as_h)

      # Invalid property type
      result = schema.validate(JSON.parse(%q({"foo": "invalid"})), output_format: "classic")
      errors = get_errors(result)
      errors.any? { |e| e["schema_pointer"].as_s.includes?("properties/foo") }.should be_true

      # Unevaluated property
      result = schema.validate(JSON.parse(%q({"bar": "unevaluated"})), output_format: "classic")
      errors = get_errors(result)
      errors.any? { |e| e["schema_pointer"].as_s.includes?("unevaluatedProperties") }.should be_true

      # Valid property + unevaluated property
      result = schema.validate(JSON.parse(%q({"foo": 1, "bar": "unevaluated"})), output_format: "classic")
      errors = get_errors(result)
      errors.any? { |e| e["schema_pointer"].as_s.includes?("unevaluatedProperties") }.should be_true
    end
  end

  describe "dependentRequired" do
    it "validates dependent required properties" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "dependentRequired": {
          "credit_card": ["billing_address"]
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({}))).should be_true
      schema.valid?(JSON.parse(%q({"billing_address": "123 Main St"}))).should be_true
      schema.valid?(JSON.parse(%q({"credit_card": "1234", "billing_address": "123 Main St"}))).should be_true
      schema.valid?(JSON.parse(%q({"credit_card": "1234"}))).should be_false
    end
  end

  describe "dependentSchemas" do
    it "validates dependent schemas" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "dependentSchemas": {
          "credit_card": {
            "required": ["billing_address"],
            "properties": {
              "billing_address": { "type": "string" }
            }
          }
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({}))).should be_true
      schema.valid?(JSON.parse(%q({"credit_card": "1234", "billing_address": "123 Main St"}))).should be_true
      schema.valid?(JSON.parse(%q({"credit_card": "1234"}))).should be_false
      schema.valid?(JSON.parse(%q({"credit_card": "1234", "billing_address": 123}))).should be_false
    end
  end

  describe "minContains and maxContains" do
    it "validates minContains" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "array",
        "contains": { "type": "integer" },
        "minContains": 2
      })).as_h)

      schema.valid?(JSON.parse(%q([1, 2]))).should be_true
      schema.valid?(JSON.parse(%q([1, 2, 3]))).should be_true
      schema.valid?(JSON.parse(%q([1]))).should be_false
      schema.valid?(JSON.parse(%q(["a", "b"]))).should be_false
    end

    it "validates maxContains" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "array",
        "contains": { "type": "integer" },
        "maxContains": 2
      })).as_h)

      schema.valid?(JSON.parse(%q([1]))).should be_true
      schema.valid?(JSON.parse(%q([1, 2]))).should be_true
      schema.valid?(JSON.parse(%q([1, 2, 3]))).should be_false
    end

    it "validates minContains and maxContains together" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "array",
        "contains": { "type": "integer" },
        "minContains": 1,
        "maxContains": 2
      })).as_h)

      schema.valid?(JSON.parse(%q([1]))).should be_true
      schema.valid?(JSON.parse(%q([1, 2]))).should be_true
      schema.valid?(JSON.parse(%q([]))).should be_false
      schema.valid?(JSON.parse(%q([1, 2, 3]))).should be_false
    end
  end

  describe "$anchor" do
    it "resolves $anchor references" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "$defs": {
          "address": {
            "$anchor": "addressSchema",
            "type": "object",
            "properties": {
              "street": { "type": "string" }
            }
          }
        },
        "type": "object",
        "properties": {
          "home": { "$ref": "#addressSchema" }
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({"home": {"street": "123 Main St"}}))).should be_true
      schema.valid?(JSON.parse(%q({"home": {"street": 123}}))).should be_false
    end
  end

  describe "$dynamicRef and $dynamicAnchor" do
    it "resolves dynamic references" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "$id": "https://example.com/schema",
        "$dynamicAnchor": "node",
        "type": "object",
        "properties": {
          "value": { "type": "integer" },
          "next": { "$dynamicRef": "#node" }
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({"value": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"value": 1, "next": {"value": 2}}))).should be_true
      schema.valid?(JSON.parse(%q({"value": "not an int"}))).should be_false
    end
  end

  describe "complex schema" do
    it "validates a comprehensive schema with multiple keywords" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "maxProperties": 4,
        "minProperties": 1,
        "required": ["one"],
        "properties": {
          "one": {
            "type": "string",
            "maxLength": 5,
            "minLength": 3,
            "pattern": "\\w+"
          },
          "two": {
            "type": "integer",
            "minimum": 10,
            "maximum": 100,
            "multipleOf": 5
          },
          "three": {
            "type": "array",
            "maxItems": 2,
            "minItems": 2,
            "uniqueItems": true,
            "contains": {
              "type": "integer"
            }
          }
        },
        "additionalProperties": {
          "type": "string"
        },
        "propertyNames": {
          "type": "string",
          "pattern": "\\w+"
        }
      })).as_h)

      data = JSON.parse(%q({
        "one": "value",
        "two": 100,
        "three": [1, 2],
        "123": "x"
      }))

      schema.valid?(data).should be_true
      result = schema.validate(data, output_format: "classic")
      get_errors(result).empty?.should be_true
    end
  end

  describe "meta-schema validation" do
    it "validates valid schemas" do
      schema = {"type" => JSON::Any.new("string")}
      JsonSchemer.valid_schema?(schema).should be_true
      result = JsonSchemer.validate_schema(schema)
      result["valid"].as_bool.should be_true
    end

    it "validates invalid schemas" do
      schema = {"type" => JSON::Any.new("invalid_type")}
      JsonSchemer.valid_schema?(schema).should be_false
      result = JsonSchemer.validate_schema(schema)
      result["valid"].as_bool.should be_false
      result["errors"].as_a.empty?.should be_false
    end

    it "validates schema with specific meta_schema" do
      schema = {"type" => JSON::Any.new("string")}
      JsonSchemer.valid_schema?(schema, meta_schema: JsonSchemer.draft202012).should be_true
    end
  end

  describe "configuration options" do
    it "validates with access_mode: read" do
      schema_hash = JSON.parse(%q({
        "type": "object",
        "properties": {
          "id": { "type": "integer", "readOnly": true },
          "secret": { "type": "string", "writeOnly": true }
        },
        "required": ["id", "secret"]
      })).as_h
      schema = JsonSchemer.schema(schema_hash, access_mode: "read")

      # In read mode, writeOnly properties (secret) are considered not required (inapplicable)
      # readOnly properties (id) are required
      schema.valid?(JSON.parse(%q({"id": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"secret": "foo"}))).should be_false # missing id
    end

    it "validates with access_mode: write" do
      schema_hash = JSON.parse(%q({
        "type": "object",
        "properties": {
          "id": { "type": "integer", "readOnly": true },
          "secret": { "type": "string", "writeOnly": true }
        },
        "required": ["id", "secret"]
      })).as_h
      schema = JsonSchemer.schema(schema_hash, access_mode: "write")

      # In write mode, readOnly properties (id) are considered not required (inapplicable)
      # writeOnly properties (secret) are required
      schema.valid?(JSON.parse(%q({"secret": "foo"}))).should be_true
      schema.valid?(JSON.parse(%q({"id": 1}))).should be_false # missing secret
    end
  end

  describe "bundle" do
    it "bundles references into a single schema" do
      # TODO: Implement Schema#bundle
      schema = JsonSchemer.schema(JSON.parse(%q({
        "$ref": "#/definitions/a",
        "definitions": {
          "a": {"type": "integer"}
        }
      })).as_h)

      bundled = schema.bundle
      bundled.as_h.should be_a(Hash(String, JSON::Any))
      bundled["$ref"]?.should_not be_nil
      bundled["allOf"]?.should be_nil
    end
  end
end
