require "./spec_helper"

describe "OpenAPI 3.2" do
  describe "document validation" do
    it "validates a basic OpenAPI 3.2 document" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
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

  describe "discriminator support (inherited from 3.1 logic)" do
    it "validates with discriminator" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
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
              "allOf": [
                {"$ref": "#/components/schemas/Pet"},
                {
                  "type": "object",
                  "properties": {
                    "meow": {"type": "boolean"}
                  }
                }
              ]
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      pet_schema = openapi.schema("Pet")

      cat = JSON.parse(%q({
        "petType": "Cat",
        "name": "Garfield",
        "meow": true
      }))
      pet_schema.valid?(cat).should be_true
    end

    it "rejects data with missing discriminator property" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
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
              "allOf": [
                {"$ref": "#/components/schemas/Pet"},
                {
                  "type": "object",
                  "properties": {
                    "meow": {"type": "boolean"}
                  }
                }
              ]
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      pet_schema = openapi.schema("Pet")

      # Missing petType property
      invalid_cat = JSON.parse(%q({
        "name": "Garfield",
        "meow": true
      }))
      pet_schema.valid?(invalid_cat).should be_false
    end

    it "rejects data with non-object value when discriminator is present" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
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
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      pet_schema = openapi.schema("Pet")

      pet_schema.valid?(JSON::Any.new("not an object")).should be_false
      pet_schema.valid?(JSON::Any.new(42_i64)).should be_false
      pet_schema.valid?(JSON::Any.new(true)).should be_false
    end

    it "validates with discriminator mapping" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
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
                  "feline": "Cat",
                  "canine": "Dog"
                }
              },
              "properties": {
                "name": {"type": "string"},
                "petType": {"type": "string"}
              },
              "required": ["name", "petType"]
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

      # Using mapping
      cat = JSON.parse(%q({
        "petType": "feline",
        "name": "Whiskers",
        "meow": true
      }))
      pet_schema.valid?(cat).should be_true

      dog = JSON.parse(%q({
        "petType": "canine",
        "name": "Rex",
        "bark": true
      }))
      pet_schema.valid?(dog).should be_true

      # Invalid - wrong type for meow property
      invalid_cat = JSON.parse(%q({
        "petType": "feline",
        "name": "Whiskers",
        "meow": "not a boolean"
      }))
      pet_schema.valid?(invalid_cat).should be_false
    end

    it "rejects invalid discriminator reference" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
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
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      pet_schema = openapi.schema("Pet")

      # Non-existent schema reference
      invalid = JSON.parse(%q({
        "petType": "NonExistent",
        "name": "Unknown"
      }))
      pet_schema.valid?(invalid).should be_false
    end
  end

  describe "OpenAPI 3.1 backward compatibility" do
    it "handles OpenAPI 3.1.1 patch version" do
      document = JSON.parse(%q({
        "openapi": "3.1.1",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {}
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_true
    end

    it "handles OpenAPI 3.2 patch versions" do
      document = JSON.parse(%q({
        "openapi": "3.2.1",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {}
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_true
    end
  end

  describe "document validation edge cases" do
    it "rejects OpenAPI document with missing required fields" do
      document = JSON.parse(%q({
        "openapi": "3.2.0"
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_false
    end

    it "validates document with webhooks instead of paths" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
        "info": {
          "title": "Webhook API",
          "version": "1.0.0"
        },
        "webhooks": {
          "newEvent": {
            "post": {
              "summary": "Receive events"
            }
          }
        }
      })).as_h

      openapi = JsonSchemer.openapi(document)
      openapi.valid?.should be_true
    end

  end
end
