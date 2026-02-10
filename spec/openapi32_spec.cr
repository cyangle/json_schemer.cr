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

    it "validates a basic OpenAPI 3.2 document with components" do
      document = JSON.parse(%q({
        "openapi": "3.2.0",
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
      openapi.valid?.should be_true
      user_schema = openapi.schema("User")
      user_schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true
      user_schema.valid?(JSON.parse(%q({"age": 30}))).should be_false
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
  end
end
