require "./spec_helper"

# NOTE: OpenAPI document validation tests are skipped because they require
# remote resource resolution for OpenAPI meta schemas.
# The schema retrieval and validation tests work correctly.

describe "OpenAPI" do
  describe "document validation" do
    it "validates a basic OpenAPI 3.1 document" do
      # This test requires OpenAPI meta schema resources to be available
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {}
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_true
    end

    it "raises for unsupported OpenAPI version" do
      document = JSON.parse(%q({
        "openapi": "2.0.0",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        }
      })).as_h

      expect_raises(JsonSchemer::UnsupportedOpenAPIVersion) do
        JsonSchemer.openapi(document)
      end
    end
  end

  describe "schema retrieval" do
    it "retrieves component schemas by name" do
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
              "properties": {
                "name": {"type": "string"},
                "age": {"type": "integer"}
              },
              "required": ["name"]
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      user_schema = openapi.schema("User")

      user_schema.valid?(JSON.parse(%q({"name": "John", "age": 30}))).should be_true
      user_schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true
      user_schema.valid?(JSON.parse(%q({"age": 30}))).should be_false # missing required name
    end
  end

  describe "discriminator" do
    # Test discriminator functionality based on OpenAPI specification example
    it "validates with discriminator" do
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": {
          "title": "Pet API",
          "version": "1.0.0"
        },
        "paths": {},
        "components": {
          "schemas": {
            "Pet": {
              "type": "object",
              "discriminator": {
                "propertyName": "petType"
              },
              "properties": {
                "name": {"type": "string"},
                "petType": {"type": "string"}
              },
              "required": ["name", "petType"]
            },
            "Cat": {
              "description": "A cat",
              "allOf": [
                {"$ref": "#/components/schemas/Pet"},
                {
                  "type": "object",
                  "properties": {
                    "huntingSkill": {
                      "type": "string",
                      "enum": ["clueless", "lazy", "adventurous", "aggressive"]
                    }
                  },
                  "required": ["huntingSkill"]
                }
              ]
            },
            "Dog": {
              "description": "A dog",
              "allOf": [
                {"$ref": "#/components/schemas/Pet"},
                {
                  "type": "object",
                  "properties": {
                    "packSize": {
                      "type": "integer",
                      "minimum": 0
                    }
                  },
                  "required": ["packSize"]
                }
              ]
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      pet_schema = openapi.schema("Pet")

      # Valid cat
      george = JSON.parse(%q({
        "petType": "Cat",
        "name": "George",
        "huntingSkill": "aggressive"
      }))
      pet_schema.valid?(george).should be_true

      # Valid dog
      edie = JSON.parse(%q({
        "petType": "Dog",
        "name": "Edie",
        "packSize": 2
      }))
      pet_schema.valid?(edie).should be_true
    end

    it "validates discriminator with mapping" do
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": {
          "title": "Pet API",
          "version": "1.0.0"
        },
        "paths": {},
        "components": {
          "schemas": {
            "Pet": {
              "type": "object",
              "discriminator": {
                "propertyName": "petType",
                "mapping": {
                  "cat": "#/components/schemas/Cat",
                  "dog": "#/components/schemas/Dog"
                }
              },
              "properties": {
                "petType": {"type": "string"}
              },
              "required": ["petType"]
            },
            "Cat": {
              "allOf": [
                {"$ref": "#/components/schemas/Pet"},
                {
                  "type": "object",
                  "properties": {
                    "meow": {"type": "boolean"}
                  }
                }
              ]
            },
            "Dog": {
              "allOf": [
                {"$ref": "#/components/schemas/Pet"},
                {
                  "type": "object",
                  "properties": {
                    "bark": {"type": "boolean"}
                  }
                }
              ]
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      pet_schema = openapi.schema("Pet")

      # Valid cat with mapping
      cat = JSON.parse(%q({
        "petType": "cat",
        "meow": true
      }))
      pet_schema.valid?(cat).should be_true

      # Valid dog with mapping
      dog = JSON.parse(%q({
        "petType": "dog",
        "bark": true
      }))
      pet_schema.valid?(dog).should be_true
    end
  end

  describe "oneOf discriminator" do
    it "validates oneOf with discriminator" do
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": {
          "title": "Shape API",
          "version": "1.0.0"
        },
        "paths": {},
        "components": {
          "schemas": {
            "Shape": {
              "oneOf": [
                {"$ref": "#/components/schemas/Circle"},
                {"$ref": "#/components/schemas/Square"}
              ],
              "discriminator": {
                "propertyName": "type"
              }
            },
            "Circle": {
              "type": "object",
              "properties": {
                "type": {"const": "Circle"},
                "radius": {"type": "number"}
              },
              "required": ["type", "radius"]
            },
            "Square": {
              "type": "object",
              "properties": {
                "type": {"const": "Square"},
                "side": {"type": "number"}
              },
              "required": ["type", "side"]
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      shape_schema = openapi.schema("Shape")

      circle = JSON.parse(%q({"type": "Circle", "radius": 5}))
      shape_schema.valid?(circle).should be_true

      square = JSON.parse(%q({"type": "Square", "side": 4}))
      shape_schema.valid?(square).should be_true
    end
  end

  describe "ref resolution in OpenAPI" do
    it "resolves refs within components" do
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {},
        "components": {
          "schemas": {
            "Address": {
              "type": "object",
              "properties": {
                "street": {"type": "string"},
                "city": {"type": "string"}
              }
            },
            "Person": {
              "type": "object",
              "properties": {
                "name": {"type": "string"},
                "address": {"$ref": "#/components/schemas/Address"}
              }
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      person_schema = openapi.schema("Person")

      valid_person = JSON.parse(%q({
        "name": "John",
        "address": {
          "street": "123 Main St",
          "city": "NYC"
        }
      }))
      person_schema.valid?(valid_person).should be_true

      invalid_person = JSON.parse(%q({
        "name": "John",
        "address": {
          "street": 123,
          "city": "NYC"
        }
      }))
      person_schema.valid?(invalid_person).should be_false
    end
  end

  describe "format validation in OpenAPI" do
    it "validates OpenAPI-specific formats" do
      document = JSON.parse(%q({
        "openapi": "3.1.0",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {},
        "components": {
          "schemas": {
            "TypedValues": {
              "type": "object",
              "properties": {
                "id": {"type": "string", "format": "uuid"},
                "email": {"type": "string", "format": "email"},
                "created": {"type": "string", "format": "date-time"}
              }
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      schema = openapi.schema("TypedValues")

      valid_data = JSON.parse(%q({
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "email": "test@example.com",
        "created": "2023-11-01T10:00:00Z"
      }))
      schema.valid?(valid_data).should be_true
    end

    it "validates int32/int64/float/double/password formats" do
      schema_hash = JSON.parse(%q({
        "properties": {
          "a": { "format": "int32" },
          "b": { "format": "int64" },
          "c": { "format": "float" },
          "d": { "format": "double" },
          "e": { "format": "password" }
        }
      })).as_h

      schemer = JsonSchemer.schema(schema_hash, meta_schema: JsonSchemer.openapi31)

      max_int32 = 2147483647
      max_int64 = 9223372036854775807_i64

      # int32
      schemer.valid?(JSON.parse(%Q({"a": #{max_int32}}))).should be_true
      # 2^31 = 2147483648
      schemer.valid?(JSON.parse(%Q({"a": 2147483648}))).should be_false

      # int64
      schemer.valid?(JSON.parse(%Q({"b": #{max_int64}}))).should be_true
      # Note: JSON.parse might parse large integers as BigInt or Int64. Crystal JSON parses int64.
      # If larger than Int64, it might fail or parse as BigInt/Float?
      # JSON.parse("9223372036854775808") raises JSON::ParseException (overflow) unless using BigInt?
      # Crystal JSON parser defaults to Int64.
      # So we can't easily test int64 overflow via JSON.parse unless we handle BigInt or use strings.
      # But format validation applies to numbers.

      # float / double
      schemer.valid?(JSON.parse(%q({"c": 2.0}))).should be_true
      schemer.valid?(JSON.parse(%q({"c": 2}))).should be_false # int is not float?
      # In Ruby test: assert(schemer.valid?({ 'c' => 2.0 })); refute(schemer.valid?({ 'c' => 2 }))
      # This implies `float` format requires Float type?
      # Let's check OpenAPI31::FORMATS in src/json_schemer/openapi31/meta.cr

      schemer.valid?(JSON.parse(%q({"d": 2.0}))).should be_true
      schemer.valid?(JSON.parse(%q({"d": 2}))).should be_false

      # password
      schemer.valid?(JSON.parse(%q({"e": "anything"}))).should be_true
      schemer.valid?(JSON.parse(%q({"e": 123}))).should be_true # format keyword validates strings generally, but if type is not enforced?
      # In Ruby test: assert(schemer.valid?({ 'e' => 2 }))
      # "password" format is just a hint, always returns true.
    end
  end
end
