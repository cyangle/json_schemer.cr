require "./spec_helper"

# Regression tests for bugs found during code review
# See: local/code_review_report.md
describe "Bug Verification Tests" do
  # Finding 1.1: Division by Zero in MultipleOf Validation (FIXED)
  # Previously: multipleOf: 0 caused DivisionByZeroError
  # Now: Raises InvalidSchema during schema parsing
  describe "multipleOf validation" do
    it "rejects multipleOf: 0 as invalid schema" do
      schema_hash = {"multipleOf" => JSON::Any.new(0_i64)} of String => JSON::Any
      expect_raises(JsonSchemer::InvalidSchema, "Value for keyword 'multipleOf' must be strictly greater than 0") do
        JsonSchemer.schema(schema_hash)
      end
    end

    it "rejects negative multipleOf as invalid schema" do
      schema_hash = {"multipleOf" => JSON::Any.new(-5_i64)} of String => JSON::Any
      expect_raises(JsonSchemer::InvalidSchema, "Value for keyword 'multipleOf' must be strictly greater than 0") do
        JsonSchemer.schema(schema_hash)
      end
    end

    it "validates multipleOf with positive number correctly" do
      schema = JsonSchemer.schema({"multipleOf" => JSON::Any.new(5_i64)} of String => JSON::Any)
      schema.valid?(JSON::Any.new(10_i64)).should be_true
      schema.valid?(JSON::Any.new(11_i64)).should be_false
      schema.valid?(JSON::Any.new(15_i64)).should be_true
    end
  end

  # Finding 2.1: ExclusiveMinimum/ExclusiveMaximum Error Messages (NOT A BUG)
  # Report claimed error messages were inverted, but they are correct.
  # Error messages describe the FAILURE condition, not the validation condition.
  describe "numeric limit error messages" do
    it "shows correct failure description for ExclusiveMaximum" do
      schema = JsonSchemer.schema({"exclusiveMaximum" => JSON::Any.new(10_i64)} of String => JSON::Any)
      result = schema.validate(JSON::Any.new(10_i64), output_format: "classic")
      result["valid"].as_bool.should be_false

      error_msg = result["errors"].as_a.first["error"].as_s
      # For exclusiveMaximum: 10, value 10 fails because it's >= 10 (not < 10)
      error_msg.should contain("greater than or equal to")
    end

    it "shows correct failure description for ExclusiveMinimum" do
      schema = JsonSchemer.schema({"exclusiveMinimum" => JSON::Any.new(0_i64)} of String => JSON::Any)
      result = schema.validate(JSON::Any.new(0_i64), output_format: "classic")
      result["valid"].as_bool.should be_false

      error_msg = result["errors"].as_a.first["error"].as_s
      # For exclusiveMinimum: 0, value 0 fails because it's <= 0 (not > 0)
      error_msg.should contain("less than or equal to")
    end

    it "shows correct failure description for Maximum" do
      schema = JsonSchemer.schema({"maximum" => JSON::Any.new(10_i64)} of String => JSON::Any)
      result = schema.validate(JSON::Any.new(11_i64), output_format: "classic")
      result["valid"].as_bool.should be_false

      error_msg = result["errors"].as_a.first["error"].as_s
      # For maximum: 10, value 11 fails because it's > 10 (not <= 10)
      error_msg.should contain("greater than")
    end

    it "shows correct failure description for Minimum" do
      schema = JsonSchemer.schema({"minimum" => JSON::Any.new(0_i64)} of String => JSON::Any)
      result = schema.validate(JSON::Any.new(-1_i64), output_format: "classic")
      result["valid"].as_bool.should be_false

      error_msg = result["errors"].as_a.first["error"].as_s
      # For minimum: 0, value -1 fails because it's < 0 (not >= 0)
      error_msg.should contain("less than")
    end
  end

  # Finding 2.2: UniqueItems deep equality (NOT A BUG)
  # Report claimed JSON::Any uses reference equality, but Crystal's
  # JSON::Any correctly implements deep equality for all types.
  describe "uniqueItems deep equality" do
    it "detects duplicate arrays with same content" do
      schema = JsonSchemer.schema({"uniqueItems" => JSON::Any.new(true)} of String => JSON::Any)
      instance = JSON.parse(%([[1, 2], [1, 2]]))
      schema.valid?(instance).should be_false
    end

    it "detects duplicate objects with same content" do
      schema = JsonSchemer.schema({"uniqueItems" => JSON::Any.new(true)} of String => JSON::Any)
      instance = JSON.parse(%([{"a": 1}, {"a": 1}]))
      schema.valid?(instance).should be_false
    end

    it "allows unique arrays with different content" do
      schema = JsonSchemer.schema({"uniqueItems" => JSON::Any.new(true)} of String => JSON::Any)
      instance = JSON.parse(%([[1, 2], [2, 1]]))
      schema.valid?(instance).should be_true
    end

    it "allows unique objects with different content" do
      schema = JsonSchemer.schema({"uniqueItems" => JSON::Any.new(true)} of String => JSON::Any)
      instance = JSON.parse(%([{"a": 1}, {"a": 2}]))
      schema.valid?(instance).should be_true
    end

    it "detects deeply nested duplicates" do
      schema = JsonSchemer.schema({"uniqueItems" => JSON::Any.new(true)} of String => JSON::Any)
      instance = JSON.parse(%([[{"a": [1, 2]}], [{"a": [1, 2]}]]))
      schema.valid?(instance).should be_false
    end

    it "handles mixed types correctly" do
      schema = JsonSchemer.schema({"uniqueItems" => JSON::Any.new(true)} of String => JSON::Any)
      instance = JSON.parse(%([1, "1", true, null]))
      schema.valid?(instance).should be_true
    end
  end
end
