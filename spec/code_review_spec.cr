require "./spec_helper"

describe "Code Review Fixes" do
  describe "1.3 Thread-safety: lazy initializers use mutex" do
    it "draft202012 returns consistent schema across calls" do
      s1 = JsonSchemer.draft202012
      s2 = JsonSchemer.draft202012
      s1.should be(s2)
    end

    it "configuration returns consistent object across calls" do
      c1 = JsonSchemer.configuration
      c2 = JsonSchemer.configuration
      c1.should be(c2)
    end
  end

  describe "3.1 resolve_uri_reference extracted to Keyword base class" do
    it "$ref still resolves correctly with fragment-only ref" do
      schema = JsonSchemer.schema(%q({
        "$defs": {
          "name": {"type": "string"}
        },
        "type": "object",
        "properties": {
          "name": {"$ref": "#/$defs/name"}
        }
      }))
      schema.valid?(JSON.parse(%q({"name": "Alice"}))).should be_true
      schema.valid?(JSON.parse(%q({"name": 42}))).should be_false
    end

    it "$dynamicRef still resolves correctly" do
      schema = JsonSchemer.schema(%q({
        "$id": "https://example.com/root",
        "$dynamicAnchor": "node",
        "type": "object",
        "properties": {
          "value": {"type": "integer"},
          "child": {"$dynamicRef": "#node"}
        }
      }))
      schema.valid?(JSON.parse(%q({"value": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"value": "x"}))).should be_false
    end
  end

  describe "Verified false positives" do
    it "1.1 multipleOf: 0 already raises InvalidSchema" do
      expect_raises(JsonSchemer::InvalidSchema, /strictly greater than 0/) do
        JsonSchemer.schema(%q({"multipleOf": 0}))
      end
    end

    it "1.1 negative multipleOf also raises InvalidSchema" do
      expect_raises(JsonSchemer::InvalidSchema, /strictly greater than 0/) do
        JsonSchemer.schema(%q({"multipleOf": -5}))
      end
    end

    it "2.2 uniqueItems handles deep equality correctly" do
      schema = JsonSchemer.schema(%q({"uniqueItems": true}))
      # Duplicate nested arrays should be invalid
      schema.valid?(JSON.parse(%q([[1,2], [1,2]]))).should be_false
      # Different nested arrays should be valid
      schema.valid?(JSON.parse(%q([[1,2], [3,4]]))).should be_true
      # Duplicate nested objects should be invalid
      schema.valid?(JSON.parse(%q([{"a": 1}, {"a": 1}]))).should be_false
      # Different nested objects should be valid
      schema.valid?(JSON.parse(%q([{"a": 1}, {"a": 2}]))).should be_true
    end

    it "2.1 ExclusiveMaximum/ExclusiveMinimum error messages are correct" do
      schema = JsonSchemer.schema(%q({"exclusiveMaximum": 10}))
      result = schema.validate(JSON::Any.new(10_i64), output_format: "classic")
      errors = result["errors"].as_a
      errors.size.should eq(1)
      # Error says "number is greater than or equal to: 10" meaning "your number is >= the limit"
      errors[0]["error"].as_s.should contain("greater than or equal to")

      schema2 = JsonSchemer.schema(%q({"exclusiveMinimum": 5}))
      result2 = schema2.validate(JSON::Any.new(5_i64), output_format: "classic")
      errors2 = result2["errors"].as_a
      errors2.size.should eq(1)
      errors2[0]["error"].as_s.should contain("less than or equal to")
    end
  end
end
