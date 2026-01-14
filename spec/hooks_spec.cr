require "./spec_helper"

# NOTE: The insert_property_defaults feature is configured but may not be fully
# implemented in the Crystal version. These tests document the expected behavior
# and verify what functionality is available.

describe "Property Defaults and Hooks" do
  describe "insert_property_defaults configuration" do
    it "accepts insert_property_defaults: true option" do
      # Should not raise an error
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
  end

  describe "default annotation behavior" do
    # The 'default' keyword is always an annotation - it doesn't affect validation
    it "default keyword does not affect validation" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "required": ["name"],
        "properties": {
          "name": {"type": "string"},
          "status": {"type": "string", "default": "active"}
        }
      })).as_h)

      # Missing status is valid (default doesn't make it required)
      schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true

      # Wrong type for status is invalid
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

  describe "no properties defined" do
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
  end

  describe "does not insert defaults when disabled" do
    it "does not modify input data by default" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "status": {"type": "string", "default": "active"}
        }
      })).as_h)

      data = JSON.parse(%q({}))
      schema.validate(data)
      # Default is not inserted
      data.as_h.has_key?("status").should be_false
    end

    it "does not insert defaults for existing properties" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "properties": {
          "status": {"type": "string", "default": "active"}
        }
      })).as_h)

      data = JSON.parse(%q({"status": "inactive"}))
      schema.validate(data)
      data.as_h["status"]?.try(&.as_s).should eq("inactive")
    end
  end
end
