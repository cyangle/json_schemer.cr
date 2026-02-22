require "./spec_helper"

describe "Invalid Schema validation" do
  it "raises InvalidSchema for negative minLength" do
    expect_raises(JsonSchemer::InvalidSchema, /Value for keyword 'minLength' must be a non-negative integer/) do
      JsonSchemer.schema({"minLength" => JSON::Any.new(-1_i64)})
    end
  end

  it "raises InvalidSchema for non-integer minItems" do
    expect_raises(JsonSchemer::InvalidSchema, /Value for keyword 'minItems' must be an integer/) do
      JsonSchemer.schema({"minItems" => JSON::Any.new(1.5)})
    end
  end

  it "raises InvalidSchema for fractional minContains" do
    expect_raises(JsonSchemer::InvalidSchema, /must be an integer/) do
      JsonSchemer.schema({"minContains" => JSON::Any.new(1.5)})
    end
  end

  it "raises InvalidSchema for string minContains" do
    expect_raises(JsonSchemer::InvalidSchema, /Value for keyword 'minContains' must be a number/) do
      JsonSchemer.schema({"minContains" => JSON::Any.new("abc")})
    end
  end

  it "raises InvalidSchema for negative maxContains" do
    expect_raises(JsonSchemer::InvalidSchema, /Value for keyword 'maxContains' must be a non-negative integer/) do
      JsonSchemer.schema({"maxContains" => JSON::Any.new(-5_i64)})
    end
  end

  it "raises InvalidSchema for non-numeric maxProperties" do
    expect_raises(JsonSchemer::InvalidSchema, /Value for keyword 'maxProperties' must be a number/) do
      JsonSchemer.schema({"maxProperties" => JSON::Any.new(true)})
    end
  end

  it "raises InvalidSchema for negative minProperties" do
    expect_raises(JsonSchemer::InvalidSchema, /Value for keyword 'minProperties' must be a non-negative integer/) do
      JsonSchemer.schema({"minProperties" => JSON::Any.new(-1_i64)})
    end
  end

  describe "Contains keyword specific validation" do
    it "raises InvalidSchema when minContains is negative even if keyword is present" do
      # This tests that Contains#after_schema_initialize also catches it
      # although it's redundant with MinContains#parse in standard cases.
      expect_raises(JsonSchemer::InvalidSchema, /Value for keyword 'minContains' must be a non-negative integer/) do
        JsonSchemer.schema({
          "contains"    => JSON::Any.new({"type" => JSON::Any.new("string")}),
          "minContains" => JSON::Any.new(-1_i64),
        })
      end
    end
  end
end
