require "./spec_helper"

describe "OpenAPI Format Integer Overflow" do
  it "does not crash when validating Int64::MIN against int32 format" do
    schema_hash = JSON.parse(%q({
      "type": "integer",
      "format": "int32"
    })).as_h
    schema = JsonSchemer.schema(schema_hash, meta_schema: JsonSchemer.openapi31_dialect_2024_11_10)
    
    # Int64::MIN is -9223372036854775808
    schema.valid?(JSON::Any.new(Int64::MIN)).should be_false
  end

  it "does not crash when validating Int64::MIN against int64 format" do
    schema_hash = JSON.parse(%q({
      "type": "integer",
      "format": "int64"
    })).as_h
    schema = JsonSchemer.schema(schema_hash, meta_schema: JsonSchemer.openapi31_dialect_2024_11_10)
    
    schema.valid?(JSON::Any.new(Int64::MIN)).should be_true
  end
end
