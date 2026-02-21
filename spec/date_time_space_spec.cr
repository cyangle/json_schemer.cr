require "./spec_helper"

describe "DATE_TIME format" do
  it "rejects space as separator" do
    schema = JsonSchemer.schema(%q({
      "type": "string",
      "format": "date-time"
    }))
    
    schema.valid?(JSON::Any.new("2023-01-01 12:00:00Z")).should be_false
    schema.valid?(JSON::Any.new("2023-01-01T12:00:00Z")).should be_true
  end
end
