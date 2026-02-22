require "./spec_helper"

describe "ReDoS security" do
  it "raises RegexMatchLimitExceeded for catastrophic backtracking" do
    schema = JsonSchemer.schema({
      "pattern" => JSON::Any.new("(a+)+$"),
    })

    # "a" * 100 + "!" should hit the backtrack limit quickly in Crystal
    instance = JSON::Any.new("a" * 100 + "!")

    expect_raises(JsonSchemer::RegexMatchLimitExceeded) do
      schema.valid?(instance)
    end
  end

  it "supports regexp_filter proc" do
    schema_hash = {"pattern" => JSON::Any.new("^[0-9]+$")}

    # Case 1: Filter allows
    schema = JsonSchemer.schema(schema_hash, regexp_filter: ->(p : String) { p.size < 100 })
    schema.valid?(JSON::Any.new("123")).should be_true

    # Case 2: Filter denies
    expect_raises(JsonSchemer::RegexFilterViolation) do
      JsonSchemer.schema(schema_hash, regexp_filter: ->(p : String) { p.size < 5 })
    end
  end

  it "catches ReDoS in patternProperties" do
    schema = JsonSchemer.schema({
      "patternProperties" => JSON::Any.new({
        "(a+)+$" => JSON::Any.new({"type" => JSON::Any.new("integer")}),
      }),
    })

    instance = JSON::Any.new({"a" * 100 + "!" => JSON::Any.new(1_i64)})

    expect_raises(JsonSchemer::RegexMatchLimitExceeded) do
      schema.valid?(instance)
    end
  end
end
