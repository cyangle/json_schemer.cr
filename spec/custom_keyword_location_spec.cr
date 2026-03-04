require "./spec_helper"

describe "Custom Keyword Location" do
  it "reports correct schema_pointer and keywordLocation for custom keywords" do
    custom_keywords = {
      "x-custom" => ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
        ["custom error"].as(Bool | Array(String))
      },
    }

    schema = JsonSchemer.schema(
      %q({
        "type": "object",
        "properties": {
          "foo": {
            "x-custom": true
          }
        }
      }),
      custom_keywords: custom_keywords
    )

    # 1. Classic format (schema_pointer should point to the schema object)
    result_classic = schema.validate(JSON.parse(%q({"foo": "bar"})), output_format: "classic")
    errors_classic = get_errors(result_classic)
    error_classic = errors_classic.first

    error_classic["type"].as_s.should eq("x-custom")
    error_classic["schema_pointer"].as_s.should eq("/properties/foo")
    error_classic["data_pointer"].as_s.should eq("/foo")

    # 2. Basic format (keywordLocation should point to the keyword itself)
    result_basic = schema.validate(JSON.parse(%q({"foo": "bar"})), output_format: "basic")
    errors_basic = result_basic["errors"].as_a
    error_basic = errors_basic.first.as_h

    error_basic["keywordLocation"].as_s.should eq("/properties/foo/x-custom")
    error_basic["instanceLocation"].as_s.should eq("/foo")
  end
end
