require "./spec_helper"

describe "Numeric Precision" do
  it "preserves precision for large integers" do
    # Int64::MAX is 9223372036854775807
    schema_hash = JSON.parse(%q({
      "maximum": 9223372036854775806
    })).as_h
    schema = JsonSchemer.schema(schema_hash)

    # 9223372036854775807 > 9223372036854775806, so it should fail
    # but as Float64 they might be equal or not. Let's see.
    schema.valid?(JSON::Any.new(Int64::MAX)).should be_false
  end
end
