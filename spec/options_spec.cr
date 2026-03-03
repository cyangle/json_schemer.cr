require "./spec_helper"

# Tests for configuration options that are accepted for API compatibility.
# Some options may not be fully implemented in the Crystal version.

describe "Configuration Options" do
  describe "keywords option" do
    it "accepts keywords option without error" do
      custom_keywords = {
        "x-custom" => ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
          true.as(Bool | Array(String))
        },
      }

      schema = JsonSchemer.schema(
        %q({"type": "string", "x-custom": true}),
        keywords: custom_keywords
      )

      schema.should be_a(JsonSchemer::Schema)
    end

    it "accepts multiple custom keywords" do
      custom_keywords = {
        "x-starts-with" => ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
          true.as(Bool | Array(String))
        },
        "x-ends-with" => ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
          true.as(Bool | Array(String))
        },
      }

      schema = JsonSchemer.schema(
        %q({"x-starts-with": "prefix", "x-ends-with": "suffix"}),
        keywords: custom_keywords
      )

      schema.should be_a(JsonSchemer::Schema)
    end

    it "stores keywords in configuration" do
      custom_keywords = {
        "x-test" => ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
          true.as(Bool | Array(String))
        },
      }

      schema = JsonSchemer.schema(
        %q({"type": "string"}),
        keywords: custom_keywords
      )

      schema.configuration.keywords.has_key?("x-test").should be_true
    end

    it "validates normally when custom keywords option is provided" do
      custom_keywords = {
        "x-custom" => ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
          true.as(Bool | Array(String))
        },
      }

      schema = JsonSchemer.schema(
        %q({"type": "string", "x-custom": true}),
        keywords: custom_keywords
      )

      # Standard validation still works
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42_i64)).should be_false
    end

    # Tests for actual custom keyword validation integration
    describe "custom keyword validation" do
      it "calls custom validator and passes when returning true" do
        called = false
        custom_keywords = {
          "x-always-valid" => ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            called = true
            true.as(Bool | Array(String))
          },
        }

        schema = JsonSchemer.schema(
          %q({"x-always-valid": true}),
          keywords: custom_keywords
        )

        schema.valid?(JSON::Any.new("test")).should be_true
        called.should be_true
      end

      it "calls custom validator and fails when returning error array" do
        custom_keywords = {
          "x-must-be-hello" => ->(instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            if instance.as_s? == "hello"
              true.as(Bool | Array(String))
            else
              ["value must be 'hello'"].as(Bool | Array(String))
            end
          },
        }

        schema = JsonSchemer.schema(
          %q({"x-must-be-hello": true}),
          keywords: custom_keywords
        )

        schema.valid?(JSON::Any.new("hello")).should be_true
        schema.valid?(JSON::Any.new("world")).should be_false
      end

      it "receives correct instance value" do
        received_instance = nil
        custom_keywords = {
          "x-capture" => ->(instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            received_instance = instance
            true.as(Bool | Array(String))
          },
        }

        schema = JsonSchemer.schema(
          %q({"x-capture": true}),
          keywords: custom_keywords
        )

        schema.valid?(JSON::Any.new("test-value"))
        received_instance.should eq(JSON::Any.new("test-value"))
      end

      it "receives correct schema value" do
        received_schema = nil
        custom_keywords = {
          "x-capture-schema" => ->(_instance : JSON::Any, schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            received_schema = schema
            true.as(Bool | Array(String))
          },
        }

        schema = JsonSchemer.schema(
          %q({"x-capture-schema": {"min": 5, "max": 10}}),
          keywords: custom_keywords
        )

        schema.valid?(JSON::Any.new("test"))
        received_schema.should_not be_nil
        received_schema.not_nil!.as_h["min"].as_i.should eq(5)
        received_schema.not_nil!.as_h["max"].as_i.should eq(10)
      end

      it "receives correct pointer for root instance" do
        received_pointer = nil
        custom_keywords = {
          "x-capture-pointer" => ->(_instance : JSON::Any, _schema : JSON::Any, pointer : String, _keyword : JsonSchemer::Keyword) {
            received_pointer = pointer
            true.as(Bool | Array(String))
          },
        }

        schema = JsonSchemer.schema(
          %q({"x-capture-pointer": true}),
          keywords: custom_keywords
        )

        schema.valid?(JSON::Any.new("test"))
        received_pointer.should eq("")
      end

      it "validates string must start with prefix" do
        custom_keywords = {
          "x-starts-with" => ->(instance : JSON::Any, schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            prefix = schema.as_s
            if str = instance.as_s?
              if str.starts_with?(prefix)
                true.as(Bool | Array(String))
              else
                ["must start with '#{prefix}'"].as(Bool | Array(String))
              end
            else
              true.as(Bool | Array(String)) # Non-strings pass
            end
          },
        }

        schema = JsonSchemer.schema(
          %q({"type": "string", "x-starts-with": "hello_"}),
          keywords: custom_keywords
        )

        schema.valid?(JSON::Any.new("hello_world")).should be_true
        schema.valid?(JSON::Any.new("world_hello")).should be_false
        schema.valid?(JSON::Any.new("hello")).should be_false
      end

      it "validates with multiple custom keywords" do
        custom_keywords = {
          "x-min-length" => ->(instance : JSON::Any, schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            min = schema.as_i
            if str = instance.as_s?
              if str.size >= min
                true.as(Bool | Array(String))
              else
                ["must be at least #{min} characters"].as(Bool | Array(String))
              end
            else
              true.as(Bool | Array(String))
            end
          },
          "x-max-length" => ->(instance : JSON::Any, schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            max = schema.as_i
            if str = instance.as_s?
              if str.size <= max
                true.as(Bool | Array(String))
              else
                ["must be at most #{max} characters"].as(Bool | Array(String))
              end
            else
              true.as(Bool | Array(String))
            end
          },
        }

        schema = JsonSchemer.schema(
          %q({"x-min-length": 3, "x-max-length": 10}),
          keywords: custom_keywords
        )

        schema.valid?(JSON::Any.new("hello")).should be_true        # 5 chars, valid
        schema.valid?(JSON::Any.new("hi")).should be_false          # 2 chars, too short
        schema.valid?(JSON::Any.new("hello world")).should be_false # 11 chars, too long
      end

      it "includes error details in validation result" do
        custom_keywords = {
          "x-must-be-even" => ->(instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            if num = instance.as_i64?
              if num.even?
                true.as(Bool | Array(String))
              else
                ["number must be even"].as(Bool | Array(String))
              end
            else
              ["value must be an integer"].as(Bool | Array(String))
            end
          },
        }

        schema = JsonSchemer.schema(
          %q({"x-must-be-even": true}),
          keywords: custom_keywords
        )

        result = schema.validate(JSON::Any.new(3_i64), output_format: "classic")
        result["valid"].as_bool.should be_false

        errors = result["errors"].as_a
        errors.size.should eq(1)
        errors[0]["type"].as_s.should eq("x-must-be-even")
      end

      it "works with nested properties" do
        custom_keywords = {
          "x-uppercase" => ->(instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            if str = instance.as_s?
              if str == str.upcase
                true.as(Bool | Array(String))
              else
                ["must be uppercase"].as(Bool | Array(String))
              end
            else
              true.as(Bool | Array(String))
            end
          },
        }

        schema = JsonSchemer.schema(
          %q({
            "type": "object",
            "properties": {
              "code": {"type": "string", "x-uppercase": true}
            }
          }),
          keywords: custom_keywords
        )

        schema.valid?(JSON.parse(%q({"code": "ABC"}))).should be_true
        schema.valid?(JSON.parse(%q({"code": "abc"}))).should be_false
      end

      it "empty error array is treated as valid" do
        custom_keywords = {
          "x-empty-errors" => ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            ([] of String).as(Bool | Array(String))
          },
        }

        schema = JsonSchemer.schema(
          %q({"x-empty-errors": true}),
          keywords: custom_keywords
        )

        schema.valid?(JSON::Any.new("test")).should be_true
      end
    end
  end

  describe "property_default_resolver option" do
    it "accepts property_default_resolver option without error" do
      resolver = ->(_value : JSON::Any, _property : String, _results : Array(Tuple(JsonSchemer::Result, Bool))) {
        true
      }

      schema = JsonSchemer.schema(
        %q({"properties": {"status": {"type": "string", "default": "active"}}}),
        property_default_resolver: resolver
      )

      schema.should be_a(JsonSchemer::Schema)
    end

    it "stores property_default_resolver in configuration" do
      resolver = ->(_value : JSON::Any, _property : String, _results : Array(Tuple(JsonSchemer::Result, Bool))) {
        true
      }

      schema = JsonSchemer.schema(
        %q({"type": "object"}),
        property_default_resolver: resolver
      )

      schema.configuration.property_default_resolver.should_not be_nil
    end

    it "validates normally when property_default_resolver is provided" do
      resolver = ->(_value : JSON::Any, _property : String, _results : Array(Tuple(JsonSchemer::Result, Bool))) {
        true
      }

      schema = JsonSchemer.schema(
        %q({"type": "object", "properties": {"name": {"type": "string"}}}),
        property_default_resolver: resolver
      )

      schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true
      schema.valid?(JSON.parse(%q({"name": 123}))).should be_false
    end

    it "conditionally inserts defaults based on resolver return value" do
      resolver = ->(value : JSON::Any, property : String, _results : Array(Tuple(JsonSchemer::Result, Bool))) {
        # Only insert defaults for "foo", skip "bar"
        property == "foo"
      }

      schema = JsonSchemer.schema(
        %q({
          "properties": {
            "foo": {"type": "string", "default": "default_foo"},
            "bar": {"type": "string", "default": "default_bar"}
          }
        }),
        insert_property_defaults: true,
        property_default_resolver: resolver
      )

      instance = JSON.parse("{}")
      schema.validate(instance)

      instance.as_h.has_key?("foo").should be_true
      instance["foo"].as_s.should eq("default_foo")

      instance.as_h.has_key?("bar").should be_false
    end

    it "passes correct arguments to the resolver" do
      captured_args = [] of Tuple(JSON::Any, String)

      resolver = ->(value : JSON::Any, property : String, _results : Array(Tuple(JsonSchemer::Result, Bool))) {
        captured_args << {value, property}
        true
      }

      schema = JsonSchemer.schema(
        %q({
          "properties": {
            "a": {"default": 1},
            "b": {"default": 2}
          }
        }),
        insert_property_defaults: true,
        property_default_resolver: resolver
      )

      instance = JSON.parse("{}")
      schema.validate(instance)

      # Sort by property name to ensure deterministic order check
      captured_args.sort_by! { |arg| arg[1] }

      captured_args.size.should eq(2)
      captured_args[0][0].as_i.should eq(1)
      captured_args[0][1].should eq("a")
      captured_args[1][0].as_i.should eq(2)
      captured_args[1][1].should eq("b")
    end

    it "allows complex logic using results argument" do
      # This test simulates a scenario where we check if the path to the default was valid
      # Note: The `results` argument contains the validation path results.
      # For a simple case, the path should be valid.

      resolver = ->(_value : JSON::Any, _property : String, results : Array(Tuple(JsonSchemer::Result, Bool))) {
        # Check if the path is valid (it should be for this simple schema)
        results.all? { |(_res, valid)| valid }
      }

      schema = JsonSchemer.schema(
        %q({
          "properties": {
            "baz": {"default": "valid_path"}
          }
        }),
        insert_property_defaults: true,
        property_default_resolver: resolver
      )

      instance = JSON.parse("{}")
      schema.validate(instance)

      instance["baz"]?.should eq("valid_path")
    end
  end

  describe "global configuration" do
    it "accepts keywords in global configuration" do
      # Store original to restore later
      original_keywords = JsonSchemer.configuration.keywords.dup

      begin
        JsonSchemer.configure do |config|
          config.keywords["x-global"] = ->(_instance : JSON::Any, _schema : JSON::Any, _pointer : String, _keyword : JsonSchemer::Keyword) {
            true.as(Bool | Array(String))
          }
        end

        JsonSchemer.configuration.keywords.has_key?("x-global").should be_true
      ensure
        # Restore original
        JsonSchemer.configuration.keywords.clear
        original_keywords.each { |k, v| JsonSchemer.configuration.keywords[k] = v }
      end
    end
  end

  describe "Configuration.new field overrides" do
    it "correctly handles boolean false values" do
      config = JsonSchemer::Configuration.new(format: false, insert_property_defaults: false)
      config.format.should be_false
      config.insert_property_defaults.should be_false
    end

    it "uses default values when not specified" do
      config = JsonSchemer::Configuration.new
      config.format.should be_true
      config.insert_property_defaults.should be_false
      config.output_format.should eq("classic")
      config.access_mode.should be_nil
      config.max_depth.should eq(50)
    end

    it "preserves all explicit values" do
      config = JsonSchemer::Configuration.new(
        format: true,
        insert_property_defaults: true,
        output_format: "basic",
        access_mode: "write",
        max_depth: 100,
      )

      config.format.should be_true
      config.insert_property_defaults.should be_true
      config.output_format.should eq("basic")
      config.access_mode.should eq("write")
      config.max_depth.should eq(100)
    end

    it "sets access_mode to a specific value" do
      config = JsonSchemer::Configuration.new(access_mode: "write")
      config.access_mode.should eq("write")
    end

    it "sets access_mode to nil" do
      config = JsonSchemer::Configuration.new(access_mode: nil)
      config.access_mode.should be_nil
    end

    it "sets vocabulary to nil" do
      config = JsonSchemer::Configuration.new(vocabulary: nil)
      config.vocabulary.should be_nil
    end

    it "sets vocabulary to a specific value" do
      vocab = {"https://example.com/vocab" => true}
      config = JsonSchemer::Configuration.new(vocabulary: vocab)
      config.vocabulary.should eq(vocab)
    end

    it "sets property_default_resolver to nil" do
      config = JsonSchemer::Configuration.new(property_default_resolver: nil)
      config.property_default_resolver.should be_nil
    end

    it "sets property_default_resolver to a value" do
      resolver = ->(value : JSON::Any, property : String, results : Array(Tuple(JsonSchemer::Result, Bool))) {
        true
      }
      config = JsonSchemer::Configuration.new(property_default_resolver: resolver)
      config.property_default_resolver.should_not be_nil
    end

    it "sets regexp_filter to nil" do
      config = JsonSchemer::Configuration.new(regexp_filter: nil)
      config.regexp_filter.should be_nil
    end

    it "sets regexp_filter to a value" do
      filter = ->(pattern : String) { !pattern.includes?("dangerous") }
      config = JsonSchemer::Configuration.new(regexp_filter: filter)
      config.regexp_filter.should_not be_nil
      config.regexp_filter.not_nil!.call("safe").should be_true
      config.regexp_filter.not_nil!.call("dangerous").should be_false
    end

    it "overrides output_format" do
      config = JsonSchemer::Configuration.new(output_format: "basic")
      config.output_format.should eq("basic")
    end

    it "overrides max_depth" do
      config = JsonSchemer::Configuration.new(max_depth: 10)
      config.max_depth.should eq(10)
    end

    it "overrides base_uri" do
      new_uri = URI.parse("https://example.com/schema")
      config = JsonSchemer::Configuration.new(base_uri: new_uri)
      config.base_uri.should eq(new_uri)
    end

    it "overrides meta_schema" do
      config = JsonSchemer::Configuration.new(meta_schema: "https://json-schema.org/draft/2019-09/schema")
      config.meta_schema.should eq("https://json-schema.org/draft/2019-09/schema")
    end

    it "overrides ref_resolver" do
      config = JsonSchemer::Configuration.new(ref_resolver: "net/http")
      config.ref_resolver.should eq("net/http")
    end

    it "creates independent instances" do
      config1 = JsonSchemer::Configuration.new(
        format: true,
        output_format: "classic",
        access_mode: "read",
        max_depth: 50,
      )

      config2 = JsonSchemer::Configuration.new(
        format: false,
        output_format: "basic",
        access_mode: nil,
        max_depth: 10,
      )

      # Both should be independent
      config1.format.should be_true
      config1.output_format.should eq("classic")
      config1.access_mode.should eq("read")
      config1.max_depth.should eq(50)

      config2.format.should be_false
      config2.output_format.should eq("basic")
      config2.access_mode.should be_nil
      config2.max_depth.should eq(10)
    end

    it "can set multiple fields at once" do
      filter = ->(pattern : String) { true }

      config = JsonSchemer::Configuration.new(
        format: false,
        insert_property_defaults: true,
        output_format: "flag",
        access_mode: "write",
        max_depth: 25,
        regexp_filter: filter,
      )

      config.format.should be_false
      config.insert_property_defaults.should be_true
      config.output_format.should eq("flag")
      config.access_mode.should eq("write")
      config.max_depth.should eq(25)
      config.regexp_filter.should eq(filter)
    end
  end
end
