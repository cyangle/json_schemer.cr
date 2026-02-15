require "./spec_helper"

describe "Property Defaults and Hooks" do
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

  describe "before/after_property_validation hooks" do
    it "calls before_property_validation hooks" do
      validated_properties = [] of String

      before_hooks = [
        ->(data : JSON::Any, property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          validated_properties << "before:#{property}"
          nil
        },
      ]

      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"}
          }
        })).as_h,
        before_property_validation: before_hooks
      )

      schema.valid?(JSON.parse(%q({"name": "John", "age": 30})))
      validated_properties.should contain("before:name")
      validated_properties.should contain("before:age")
    end

    it "calls after_property_validation hooks" do
      validated_properties = [] of String

      after_hooks = [
        ->(data : JSON::Any, property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          validated_properties << "after:#{property}"
          nil
        },
      ]

      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"}
          }
        })).as_h,
        after_property_validation: after_hooks
      )

      schema.valid?(JSON.parse(%q({"name": "John", "age": 30})))
      validated_properties.should contain("after:name")
      validated_properties.should contain("after:age")
    end

    it "calls hooks in correct order (before, validate, after)" do
      call_log = [] of String

      before_hooks = [
        ->(_data : JSON::Any, property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          call_log << "before:#{property}"
          nil
        },
      ]

      after_hooks = [
        ->(_data : JSON::Any, property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          call_log << "after:#{property}"
          nil
        },
      ]

      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "type": "object",
          "properties": {
            "name": {"type": "string"}
          }
        })).as_h,
        before_property_validation: before_hooks,
        after_property_validation: after_hooks
      )

      schema.valid?(JSON.parse(%q({"name": "John"})))
      call_log.should eq(["before:name", "after:name"])
    end

    it "receives correct instance and property" do
      received_values = {} of String => JSON::Any

      before_hooks = [
        ->(data : JSON::Any, property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          if data.as_h.has_key?(property)
            received_values[property] = data.as_h[property]
          end
          nil
        },
      ]

      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"}
          }
        })).as_h,
        before_property_validation: before_hooks
      )

      schema.valid?(JSON.parse(%q({"name": "John", "age": 30})))
      received_values["name"]?.try(&.as_s).should eq("John")
      received_values["age"]?.try(&.as_i).should eq(30)
    end

    it "calls hooks for missing properties" do
      validated_properties = [] of String

      before_hooks = [
        ->(_data : JSON::Any, property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          validated_properties << property
          nil
        },
      ]

      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"}
          }
        })).as_h,
        before_property_validation: before_hooks
      )

      schema.valid?(JSON.parse(%q({"name": "John"})))
      validated_properties.should contain("name")
      validated_properties.should contain("age")
    end

    it "supports multiple hooks" do
      call_log = [] of String

      before_hooks = [
        ->(_data : JSON::Any, property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          call_log << "hook1:#{property}"
          nil
        },
        ->(_data : JSON::Any, property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          call_log << "hook2:#{property}"
          nil
        },
      ]

      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "type": "object",
          "properties": {
            "name": {"type": "string"}
          }
        })).as_h,
        before_property_validation: before_hooks
      )

      schema.valid?(JSON.parse(%q({"name": "John"})))
      call_log.should eq(["hook1:name", "hook2:name"])
    end

    it "does not call hooks for non-object instances" do
      called = false

      before_hooks = [
        ->(_data : JSON::Any, _property : String, _property_schema : JSON::Any, _parent : JSON::Any) {
          called = true
          nil
        },
      ]

      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "name": {"type": "string"}
          }
        })).as_h,
        before_property_validation: before_hooks
      )

      schema.valid?(JSON::Any.new("just a string"))
      called.should be_false
    end

    it "persists modifications to original data" do
      cast_hook = ->(instance : JSON::Any, property : String, _prop_schema : JSON::Any, _parent : JSON::Any) {
        if property == "age" && instance.as_h.has_key?("age")
          val = instance.as_h["age"]
          if val.raw.is_a?(String)
            begin
              instance.as_h["age"] = JSON::Any.new(val.as_s.to_i64)
            rescue
            end
          end
        end
        nil
      }

      schema = JsonSchemer.schema(
        JSON.parse(%q({
          "properties": {
            "age": {"type": "integer"}
          }
        })).as_h,
        before_property_validation: [cast_hook]
      )

      data = JSON.parse(%q({"age": "123"}))
      schema.validate(data)
      
      # Original data should be modified
      data["age"].as_i.should eq(123)
    end
  end
end
