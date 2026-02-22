require "./spec_helper"

describe "Property Defaults" do
  describe "insert_property_defaults" do
    it "accepts insert_property_defaults: true option" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "status": {"type": "string", "default": "active"}
          }
        })).as_h,
        insert_property_defaults: true
      )
      schema.should be_a(JsonSchemer::Schema)
    end

    it "accepts insert_property_defaults: false option" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "status": {"type": "string", "default": "active"}
          }
        })).as_h,
        insert_property_defaults: false
      )
      schema.should be_a(JsonSchemer::Schema)
    end

    it "inserts defaults into missing properties when enabled" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "status": {"type": "string", "default": "active"},
            "count": {"type": "integer", "default": 0}
          }
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({}))
      schema.validate(data)
      data.as_h["status"]?.try(&.as_s).should eq("active")
      data.as_h["count"]?.try(&.as_i).should eq(0)
    end

    it "does not overwrite existing properties" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "status": {"type": "string", "default": "active"}
          }
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({"status": "inactive"}))
      schema.validate(data)
      data.as_h["status"]?.try(&.as_s).should eq("inactive")
    end

    it "does not insert defaults when disabled (default)" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "status": {"type": "string", "default": "active"}
        }
      })).as_h)

      data = JSON.parse(%q({}))
      schema.validate(data)
      data.as_h.has_key?("status").should be_false
    end

    it "re-validates after inserting defaults" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "required": ["status"],
          "properties": {
            "status": {"type": "string", "default": "active"}
          }
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({}))
      result = schema.validate(data)
      result["valid"].as_bool.should be_true
      data.as_h["status"]?.try(&.as_s).should eq("active")
    end

    it "inserts defaults in nested objects" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "user": {
              "type": "object",
              "properties": {
                "role": {"type": "string", "default": "viewer"}
              }
            }
          }
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({"user": {}}))
      schema.validate(data)
      data.as_h["user"].as_h["role"]?.try(&.as_s).should eq("viewer")
    end

    it "does not fail when no properties are defined" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "$comment": "Mostly empty schema"
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({"a": 1}))
      schema.valid?(data).should be_true
    end

    it "does not fail with boolean property schema" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "a": true
          }
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({"a": 1}))
      schema.valid?(data).should be_true
    end

    it "handles various default value types" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "flag": {"type": "boolean", "default": false},
            "tags": {"type": "array", "default": []},
            "meta": {"type": "object", "default": {}}
          }
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({}))
      schema.validate(data)
      data.as_h["flag"]?.try(&.as_bool).should eq(false)
      data.as_h["tags"]?.try(&.as_a).should eq([] of JSON::Any)
      data.as_h["meta"]?.try(&.as_h).should eq({} of String => JSON::Any)
    end

    it "does not mutate the schema default value when the instance is modified" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "tags": {
              "type": "array",
              "default": ["initial"]
            }
          }
        })).as_h,
        insert_property_defaults: true
      )

      # First validation: get default
      data1 = JSON.parse(%q({}))
      schema.validate(data1)

      tags1 = data1.as_h["tags"].as_a
      tags1.should eq([JSON::Any.new("initial")])

      # Mutate the inserted default value
      tags1 << JSON::Any.new("modified")

      # Verify mutation happened in data1
      data1.as_h["tags"].as_a.should eq([JSON::Any.new("initial"), JSON::Any.new("modified")])

      # Second validation: should get fresh default
      data2 = JSON.parse(%q({}))
      schema.validate(data2)

      tags2 = data2.as_h["tags"].as_a
      # This assertion ensures default_value is cloned
      tags2.should eq([JSON::Any.new("initial")])
    end
  end

  describe "default annotation behavior" do
    it "default keyword does not affect validation" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "required": ["name"],
        "properties": {
          "name": {"type": "string"},
          "status": {"type": "string", "default": "active"}
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true
      schema.valid?(JSON.parse(%q({"name": "John", "status": 123}))).should be_false
    end

    it "validates default values correctly when provided" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "count": {"type": "integer", "default": 0}
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({"count": 5}))).should be_true
      schema.valid?(JSON.parse(%q({"count": "five"}))).should be_false
    end
  end
  describe "default conflicts" do
    it "logs warning when multiple allOf branches have conflicting defaults" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "allOf": [
            {
              "properties": {
                "status": {"type": "string", "default": "active"}
              }
            },
            {
              "properties": {
                "status": {"type": "string", "default": "inactive"}
              }
            }
          ]
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({}))

      # Capture log output
      backend = Log::MemoryBackend.new
      Log.builder.bind("*", :warn, backend)

      schema.validate(data)
      # Property should NOT be inserted due to conflict
      data.as_h.has_key?("status").should be_false
      found_conflict_warning = backend.entries.any? do |entry|
        entry.message.includes?("default conflict") || entry.message.includes?("conflicting default")
      end
      found_conflict_warning.should be_true
    end

    it "applies default when allOf branches have same default values" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "allOf": [
            {
              "properties": {
                "status": {"type": "string", "default": "active"}
              }
            },
            {
              "properties": {
                "status": {"type": "string", "default": "active"}
              }
            }
          ]
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({}))
      schema.validate(data)

      # Property SHOULD be inserted because defaults match
      data.as_h["status"]?.try(&.as_s).should eq("active")
    end

    it "logs warning with property name and instance location" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "allOf": [
            {
              "properties": {
                "config": {
                  "type": "object",
                  "properties": {
                    "enabled": {"type": "boolean", "default": true}
                  }
                }
              }
            },
            {
              "properties": {
                "config": {
                  "type": "object",
                  "properties": {
                    "enabled": {"type": "boolean", "default": false}
                  }
                }
              }
            }
          ]
        })).as_h,
        insert_property_defaults: true
      )

      data = JSON.parse(%q({"config": {}}))

      backend = Log::MemoryBackend.new
      Log.builder.bind("*", :warn, backend)
      schema.validate(data)

      # Should have logged warning with context
      found_context_warning = backend.entries.any? do |entry|
        entry.message.includes?("/config/enabled") ||
          (entry.message.includes?("enabled") && entry.message.includes?("config"))
      end
      found_context_warning.should be_true
    end
  end
end
