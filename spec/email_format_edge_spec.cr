require "./spec_helper"

describe "Email Format Parsing Edge Case" do
  it "handles escaped quotes correctly" do
    # "\"test\""@example.com is valid RFC 5322
    schema = JsonSchemer.schema(%q({
      "type": "string",
      "format": "email"
    }))
    
    schema.valid?(JSON::Any.new(%q{"\"test\""@example.com})).should be_true
  end
end
