require "./spec_helper"

describe "Depth Security" do
  it "raises MaximumDepthExceeded on deeply nested json" do
    schema_json = %q({"anyOf": [{"type": "null"}, {"type": "object", "properties": {"a": {"$ref": "#"}}}]})
    schema = JsonSchemer.schema(schema_json)

    # Create deeply nested json
    instance = {"a" => JSON::Any.new(nil)}
    100.times do
      instance = {"a" => JSON::Any.new(instance)}
    end

    expect_raises(JsonSchemer::MaximumDepthExceeded, /Maximum validation depth of 50 exceeded/) do
      schema.valid?(JSON::Any.new(instance))
    end
  end

  it "allows customizing max_depth via schema kwargs" do
    schema_json = %q({"anyOf": [{"type": "null"}, {"type": "object", "properties": {"a": {"$ref": "#"}}}]})
    schema = JsonSchemer.schema(schema_json, max_depth: 5)

    # Create nested json depth 10
    instance = {"a" => JSON::Any.new(nil)}
    10.times do
      instance = {"a" => JSON::Any.new(instance)}
    end

    expect_raises(JsonSchemer::MaximumDepthExceeded, /Maximum validation depth of 5 exceeded/) do
      schema.valid?(JSON::Any.new(instance))
    end
  end

  it "does not raise when under max_depth" do
    schema_json = %q({"anyOf": [{"type": "null"}, {"type": "object", "properties": {"a": {"$ref": "#"}}}]})
    schema = JsonSchemer.schema(schema_json, max_depth: 10)

    # Under depth 10 should pass
    instance = {"a" => JSON::Any.new(nil)}
    1.times do
      instance = {"a" => JSON::Any.new(instance)}
    end
    schema.valid?(JSON::Any.new(instance)).should be_true
  end

  describe "max_depth validation" do
    it "raises ArgumentError when max_depth is 0" do
      expect_raises(ArgumentError, /max_depth must be > 0/) do
        JsonSchemer.schema(%q({"type": "string"}), max_depth: 0)
      end
    end

    it "raises ArgumentError when max_depth is negative" do
      expect_raises(ArgumentError, /max_depth must be > 0, got: -1/) do
        JsonSchemer.schema(%q({"type": "string"}), max_depth: -1)
      end
    end

    it "accepts max_depth of 1" do
      schema = JsonSchemer.schema(%q({"type": "string"}), max_depth: 1)
      schema.valid?(JSON::Any.new("hello")).should be_true
    end
  end
end
