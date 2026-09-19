require "./spec_helper"

describe "Regex Validation" do
  describe "pattern keyword" do
    it "validates basic patterns" do
      schema = JsonSchemer.schema(JSON.parse(%q({"pattern": "^foo$"})).as_h)
      schema.valid?(JSON::Any.new("foo")).should be_true
      schema.valid?(JSON::Any.new(" foo")).should be_false
      schema.valid?(JSON::Any.new("foo ")).should be_false
    end

    it "handles anchors in patterns" do
      schema = JsonSchemer.schema(JSON.parse(%q({"pattern": "^test$"})).as_h)
      schema.valid?(JSON::Any.new("test")).should be_true
      # Note: Crystal's regex handling differs from Ruby
      # The pattern must actually match the string for validation to pass
    end

    it "validates pattern with character classes" do
      schema = JsonSchemer.schema(JSON.parse(%q({"pattern": "^[a-z]+$"})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("Hello")).should be_false
      schema.valid?(JSON::Any.new("hello123")).should be_false
    end

    it "validates pattern with digits" do
      schema = JsonSchemer.schema(JSON.parse(%q({"pattern": "^\\d+$"})).as_h)
      schema.valid?(JSON::Any.new("12345")).should be_true
      schema.valid?(JSON::Any.new("abc")).should be_false
    end

    it "validates pattern with word characters" do
      schema = JsonSchemer.schema(JSON.parse(%q({"pattern": "^\\w+$"})).as_h)
      schema.valid?(JSON::Any.new("hello_123")).should be_true
      schema.valid?(JSON::Any.new("hello-123")).should be_false
    end
  end

  describe "patternProperties" do
    it "validates properties matching pattern" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "patternProperties": {
          "^x-": {"type": "string"}
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({"x-custom": "value"}))).should be_true
      schema.valid?(JSON.parse(%q({"x-other": "also valid"}))).should be_true
      schema.valid?(JSON.parse(%q({"x-bad": 123}))).should be_false
      schema.valid?(JSON.parse(%q({"normal": 123}))).should be_true # doesn't match pattern
    end

    it "validates multiple pattern properties" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "patternProperties": {
          "^S_": {"type": "string"},
          "^I_": {"type": "integer"}
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({"S_name": "test", "I_count": 5}))).should be_true
      schema.valid?(JSON.parse(%q({"S_name": 5}))).should be_false
      schema.valid?(JSON.parse(%q({"I_count": "five"}))).should be_false
    end
  end

  describe "format regex validation" do
    it "validates regex format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "regex"})).as_h)
      schema.valid?(JSON::Any.new("^[a-z]+$")).should be_true
      schema.valid?(JSON::Any.new(".*")).should be_true
      schema.valid?(JSON::Any.new("\\d+")).should be_true
    end

    it "handles NUL character in regex" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "regex"})).as_h)
      schema.valid?(JSON::Any.new("\\0")).should be_true
    end
  end

  describe "complex patterns" do
    it "validates UUID-like patterns" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
      })).as_h)

      schema.valid?(JSON::Any.new("550e8400-e29b-41d4-a716-446655440000")).should be_true
      schema.valid?(JSON::Any.new("1122-112")).should be_false
      schema.valid?(JSON::Any.new("not-a-uuid")).should be_false
    end

    it "validates email-like patterns" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "pattern": "^[^@]+@[^@]+$"
      })).as_h)

      schema.valid?(JSON::Any.new("test@example.com")).should be_true
      schema.valid?(JSON::Any.new("no-at-sign")).should be_false
    end
  end

  describe "propertyNames with pattern" do
    it "validates property names against pattern" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "propertyNames": {
          "pattern": "^[a-z]+$"
        }
      })).as_h)

      schema.valid?(JSON.parse(%q({"foo": 1, "bar": 2}))).should be_true
      schema.valid?(JSON.parse(%q({"Foo": 1}))).should be_false
      schema.valid?(JSON.parse(%q({"foo_bar": 1}))).should be_false
    end
  end

  # Regression tests for ECMA-262 conformance gaps found during review.
  describe "format regex ECMA-262 conformance" do
    it "rejects PCRE-only group constructs" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "regex"})).as_h)
      ["(?>a)", "(?R)", "(?0)", "(?|a|b)", "(a)(?(1)b|c)"].each do |pattern|
        schema.valid?(JSON::Any.new(pattern)).should be_false
      end
    end

    it "rejects possessive quantifiers" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "regex"})).as_h)
      ["a++", "a*+", "a?+", "a{2,3}+"].each do |pattern|
        schema.valid?(JSON::Any.new(pattern)).should be_false
      end
    end

    it "accepts ECMA-262 lazy quantifiers and flag groups" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "regex"})).as_h)
      ["a*?", "a+?", "a??", "a{1,2}?", "(?i:x)", "(?<name>x)"].each do |pattern|
        schema.valid?(JSON::Any.new(pattern)).should be_true
      end
    end

    it "accepts variable-width lookbehind patterns that ECMA-262 allows" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "regex"})).as_h)
      ["(?<=a+)b", "(?<=ab+)c", "(?<=x\\w+)", "(?<=a*b)", "(?<=a{200,}b+)", "(?<=a{256,})b"].each do |pattern|
        schema.valid?(JSON::Any.new(pattern)).should be_true
      end
    end

    it "treats an empty character class as never matching" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({"not": {"pattern": "[]x]"}})).as_h,
        regexp_resolver: "ecma"
      )
      schema.valid?(JSON::Any.new("x")).should be_true
      schema.valid?(JSON::Any.new("]")).should be_true

      schema = JsonSchemer.schema(
        JSON.parse(%q({"not": {"pattern": "[]]"}})).as_h,
        regexp_resolver: "ecma"
      )
      schema.valid?(JSON::Any.new("]")).should be_true
    end

    it "treats [^] as matching any character when followed by another class" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({"not": {"pattern": "[^][a-z]"}})).as_h,
        regexp_resolver: "ecma"
      )
      # [^][a-z] requires two characters, so a single character never matches.
      schema.valid?(JSON::Any.new("5")).should be_true
      schema.valid?(JSON::Any.new("a")).should be_true
    end

    it "does not rewrite lookbehind-like text inside a character class" do
      schema = JsonSchemer.schema(
        JSON.parse(%q({"pattern": "[(?<=a+)]"})).as_h,
        regexp_resolver: "ecma"
      )
      # The class contains a literal '+', so it must still match it.
      schema.valid?(JSON::Any.new("+")).should be_true
    end
  end
end
