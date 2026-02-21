require "./spec_helper"

describe JsonSchemer::Result do
  describe "protection against schema modification" do
    it "prevents direct access to the source schema" do
      public_methods = {{ JsonSchemer::Result.methods.select { |m| m.visibility == :public }.map(&.name.stringify) }}

      public_methods.should_not contain("source")
      public_methods.should_not contain("source=")
    end

    it "prevents modifying the original schema via classic output" do
      schema_json = %({"type": "string"})
      schema = JsonSchemer.schema(schema_json)

      results = schema.validate(JSON::Any.new(123_i64), output_format: "classic")

      errors = results["errors"].as_a
      classic_error = errors.first.as_h

      classic_error["schema"].as_h["type"] = JSON::Any.new("number")

      schema.value.as_h["type"].as_s.should eq("string")

      classic_error["root_schema"].as_h["type"] = JSON::Any.new("boolean")
      schema.root.value.as_h["type"].as_s.should eq("string")
    end

    it "prevents modifying the original schema via details in classic output" do
      schema = JsonSchemer.schema(%({
        "type": "object",
        "required": ["name", "email"]
      }))

      results = schema.validate(JSON::Any.new({} of String => JSON::Any), output_format: "classic")
      errors = results["errors"].as_a
      classic_error = errors.first.as_h

      details = classic_error["details"].as_h
      missing = details["missing_keys"].as_a

      missing << JSON::Any.new("hacked")

      results2 = schema.validate(JSON::Any.new({} of String => JSON::Any), output_format: "classic")
      errors2 = results2["errors"].as_a
      classic_error2 = errors2.first.as_h
      details2 = classic_error2["details"].as_h

      missing_keys = details2["missing_keys"].as_a.map(&.as_s)
      missing_keys.size.should eq(2)
      missing_keys.should contain("name")
      missing_keys.should contain("email")
      missing_keys.should_not contain("hacked")
    end

    it "prevents modifying the original schema via annotation in output" do
      # unevaluatedProperties generates an annotation
      schema = JsonSchemer.schema(%({
        "type": "object",
        "unevaluatedProperties": false
      }))

      valid_data = JSON::Any.new({"foo" => JSON::Any.new("baz")} of String => JSON::Any)
      # Unevaluated properties returns true if it has no subschemas (false) to evaluate
      # wait, "unevaluatedProperties": false with a property "foo" is invalid.
      # Let's make a schema that generates an explicit annotation array.
      schema2 = JsonSchemer.schema(%({
        "properties": {
          "foo": {"type": "string"}
        }
      }))

      results = schema2.validate(valid_data, output_format: "detailed")

      # The detailed output recursively nests. Let's find an annotation array
      # properties keyword generates an annotation of the keys it processed

      # For a simpler approach, let's just create a custom Result manually that has
      # an annotation array to test Result#to_output_unit directly, which is what builds
      # the json hash.

      # We just want to test Result#result_annotation and Result#to_output_unit isolation
      schema_ref = schema2.as(JsonSchemer::Schema)
      original_ann = JSON::Any.new([JSON::Any.new("foo")])

      result = JsonSchemer::Result.new(
        source: schema_ref,
        instance: valid_data,
        instance_location: JsonSchemer::Location.root,
        keyword_location: JsonSchemer::Location.root,
        valid: true,
        result_annotation: original_ann
      )

      # Check that getter is cloned
      got_ann = result.result_annotation.not_nil!
      got_ann.as_a << JSON::Any.new("hacked")

      # Ensure original not touched by getter mutation
      result.result_annotation.not_nil!.as_a.map(&.as_s).should eq(["foo"])

      # Check that output unit is cloned
      output_hash = result.to_output_unit
      out_ann = output_hash["annotation"].as_a
      out_ann << JSON::Any.new("hacked_output")

      # Ensure original not touched by output mutation
      result.result_annotation.not_nil!.as_a.map(&.as_s).should eq(["foo"])
    end
  end
end
