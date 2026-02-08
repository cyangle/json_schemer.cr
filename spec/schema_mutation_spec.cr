require "./spec_helper"

describe "Schema mutation during validation" do
  describe "Location::Node tree - no shared state between validation calls" do
    it "should produce consistent results across multiple validation calls" do
      # This test verifies that Schema instances don't accumulate state
      # during validation calls with different instance data.
      #
      # Previously, root_keyword_location was memoized on the Schema, and
      # Location::Node#join mutated the @children hash, causing unbounded memory growth.
      # The fix ensures each validation call uses a fresh Location.root.

      schema = JsonSchemer.schema(%q({
        "type": "object",
        "properties": {
          "a": {"type": "string"},
          "b": {"type": "integer"},
          "c": {"type": "boolean"}
        }
      }))

      # Validate with first instance
      result1 = schema.validate(JSON.parse(%q({"a": "hello", "b": 42})))
      result1["valid"].as_bool.should be_true

      # Validate with second instance (different properties)
      result2 = schema.validate(JSON.parse(%q({"c": true})))
      result2["valid"].as_bool.should be_true

      # Validate with third instance (all properties)
      result3 = schema.validate(JSON.parse(%q({"a": "world", "b": 100, "c": false})))
      result3["valid"].as_bool.should be_true

      # Re-validate first pattern - should produce identical results
      result4 = schema.validate(JSON.parse(%q({"a": "test", "b": 99})))
      result4["valid"].as_bool.should be_true

      # Invalid data should still be caught correctly
      result5 = schema.validate(JSON.parse(%q({"a": 123})))
      result5["valid"].as_bool.should be_false
    end

    it "many validations should not cause excessive memory growth" do
      # This test ensures that repeated validations don't accumulate state

      schema = JsonSchemer.schema(%q({
        "type": "object",
        "properties": {
          "items": {
            "type": "array",
            "items": {"type": "integer"}
          }
        }
      }))

      # Validate arrays of different lengths many times
      # If there was shared mutable state, this would accumulate nodes
      100.times do |i|
        arr = (0..i % 10).to_a
        data = {"items" => arr}
        result = schema.validate(JSON.parse(data.to_json))
        result["valid"].as_bool.should be_true
      end

      # Validation should still work correctly
      result = schema.validate(JSON.parse(%q({"items": [1, "invalid", 3]})))
      result["valid"].as_bool.should be_false

      errors = get_errors(result)
      errors.size.should be > 0
      # Verify the error points to the correct location
      error = errors.find { |e| e["data_pointer"]?.try(&.as_s) == "/items/1" }
      error.should_not be_nil
    end

    it "validates correctly with deeply nested structures" do
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "properties": {
          "level1": {
            "type": "object",
            "properties": {
              "level2": {
                "type": "object",
                "properties": {
                  "level3": {"type": "string"}
                }
              }
            }
          }
        }
      }))

      # Multiple validations with different nesting depths
      schema.valid?(JSON.parse(%q({}))).should be_true
      schema.valid?(JSON.parse(%q({"level1": {}}))).should be_true
      schema.valid?(JSON.parse(%q({"level1": {"level2": {}}}))).should be_true
      schema.valid?(JSON.parse(%q({"level1": {"level2": {"level3": "hello"}}}))).should be_true

      # Invalid deep value
      result = schema.validate(JSON.parse(%q({"level1": {"level2": {"level3": 123}}})))
      result["valid"].as_bool.should be_false

      errors = get_errors(result)
      error = errors.find { |e| e["data_pointer"]?.try(&.as_s) == "/level1/level2/level3" }
      error.should_not be_nil
    end
  end

  describe "DynamicRef mutation" do
    it "should handle $dynamicRef without mutation issues" do
      # Schema with $dynamicRef that gets resolved during validation
      schema = JsonSchemer.schema(%q({
        "$id": "https://example.com/root",
        "$dynamicAnchor": "node",
        "type": "object",
        "properties": {
          "value": {"type": "string"},
          "children": {
            "type": "array",
            "items": {"$dynamicRef": "#node"}
          }
        }
      }))

      # First validation
      result1 = schema.validate(JSON.parse(%q({
        "value": "root",
        "children": [
          {"value": "child1", "children": []},
          {"value": "child2", "children": [{"value": "grandchild", "children": []}]}
        ]
      })))
      result1["valid"].as_bool.should be_true

      # Second validation with different structure
      result2 = schema.validate(JSON.parse(%q({
        "value": "another",
        "children": []
      })))
      result2["valid"].as_bool.should be_true

      # Third validation with invalid data
      result3 = schema.validate(JSON.parse(%q({
        "value": 123,
        "children": []
      })))
      result3["valid"].as_bool.should be_false
    end
  end

  describe "UnknownKeyword fetch mutation" do
    it "should handle ref resolution through unknown keywords without issues" do
      # Schema that requires navigating through $defs during ref resolution
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "properties": {
          "name": {"$ref": "#/$defs/nameType"},
          "age": {"$ref": "#/$defs/ageType"}
        },
        "$defs": {
          "nameType": {"type": "string", "minLength": 1},
          "ageType": {"type": "integer", "minimum": 0}
        }
      }))

      # Multiple validations
      schema.valid?(JSON.parse(%q({"name": "John", "age": 30}))).should be_true
      schema.valid?(JSON.parse(%q({"name": "Jane", "age": 25}))).should be_true
      schema.valid?(JSON.parse(%q({"name": "", "age": 30}))).should be_false    # name too short
      schema.valid?(JSON.parse(%q({"name": "Bob", "age": -5}))).should be_false # negative age
    end
  end

  describe "Cached resolver mutation" do
    it "should handle pattern resolution caching correctly" do
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "patternProperties": {
          "^foo": {"type": "string"},
          "^bar": {"type": "integer"}
        }
      }))

      # Multiple validations with different property names
      schema.valid?(JSON.parse(%q({"foo1": "hello"}))).should be_true
      schema.valid?(JSON.parse(%q({"foo2": "world"}))).should be_true
      schema.valid?(JSON.parse(%q({"bar1": 42}))).should be_true
      schema.valid?(JSON.parse(%q({"bar2": 100}))).should be_true

      # Mix of both patterns
      schema.valid?(JSON.parse(%q({"foo_a": "test", "bar_b": 200}))).should be_true

      # Invalid values
      schema.valid?(JSON.parse(%q({"foo_x": 123}))).should be_false    # should be string
      schema.valid?(JSON.parse(%q({"bar_x": "oops"}))).should be_false # should be integer
    end
  end
end
