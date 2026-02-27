require "./spec_helper"

describe "Custom Format Validator Exceptions" do
  it "catches exceptions and treats them as validation failure" do
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

    result = schema.validate(JSON.parse(%q("test string")))

    result["valid"].as_bool.should be_false

    # In classic format, the error should mention the crash
    errors = result["errors"].as_a
    errors.size.should eq(1)

    details = errors.first["details"].as_h
    details["error"].as_s.should contain("Validator raised Exception: Oops, validator crashed")
  end
end
