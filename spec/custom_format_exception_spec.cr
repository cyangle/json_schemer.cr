require "./spec_helper"

describe "Custom Format Validator Exceptions" do
  it "does not catch general exceptions from custom validators" do
    custom_formats = {
      "buggy" => ->(value : JSON::Any, format : String) {
        raise Exception.new("Oops, validator crashed")
        true
      },
    }

    schema = JsonSchemer.schema(
      JSON.parse(%q({"type": "string", "format": "buggy"})).as_h,
      format: true,
      formats: custom_formats
    )

    expect_raises(Exception, "Oops, validator crashed") do
      schema.validate(JSON.parse(%q("test string")))
    end
  end
end
