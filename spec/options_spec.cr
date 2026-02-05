require "./spec_helper"

# Tests for configuration options that are accepted for API compatibility.
# Some options may not be fully implemented in the Crystal version.

describe "Configuration Options" do
  describe "keywords option" do
    it "accepts keywords option without error" do
      custom_keywords = {
        "x-custom" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
        "x-starts-with" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
          true.as(Bool | Array(String))
        },
        "x-ends-with" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
        "x-test" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
        "x-custom" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-always-valid" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-must-be-hello" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-capture" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-capture-schema" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-capture-pointer" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-starts-with" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-min-length" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-max-length" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-must-be-even" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-uppercase" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
          "x-empty-errors" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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
      resolver = ->(value : JSON::Any, property : String, results : Array(Tuple(JsonSchemer::Result, Bool))) {
        true
      }

      schema = JsonSchemer.schema(
        %q({"properties": {"status": {"type": "string", "default": "active"}}}),
        property_default_resolver: resolver
      )

      schema.should be_a(JsonSchemer::Schema)
    end

    it "stores property_default_resolver in configuration" do
      resolver = ->(value : JSON::Any, property : String, results : Array(Tuple(JsonSchemer::Result, Bool))) {
        true
      }

      schema = JsonSchemer.schema(
        %q({"type": "object"}),
        property_default_resolver: resolver
      )

      schema.configuration.property_default_resolver.should_not be_nil
    end

    it "validates normally when property_default_resolver is provided" do
      resolver = ->(value : JSON::Any, property : String, results : Array(Tuple(JsonSchemer::Result, Bool))) {
        true
      }

      schema = JsonSchemer.schema(
        %q({"type": "object", "properties": {"name": {"type": "string"}}}),
        property_default_resolver: resolver
      )

      schema.valid?(JSON.parse(%q({"name": "John"}))).should be_true
      schema.valid?(JSON.parse(%q({"name": 123}))).should be_false
    end
  end

  describe "resolve_enumerators option" do
    it "accepts resolve_enumerators: true option" do
      schema = JsonSchemer.schema(
        %q({"type": "string"}),
        resolve_enumerators: true
      )

      schema.should be_a(JsonSchemer::Schema)
    end

    it "accepts resolve_enumerators: false option" do
      schema = JsonSchemer.schema(
        %q({"type": "string"}),
        resolve_enumerators: false
      )

      schema.should be_a(JsonSchemer::Schema)
    end

    it "stores resolve_enumerators in configuration" do
      schema = JsonSchemer.schema(
        %q({"type": "string"}),
        resolve_enumerators: true
      )

      schema.configuration.resolve_enumerators.should be_true
    end

    it "defaults to false" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      schema.configuration.resolve_enumerators.should be_false
    end

    it "can be passed to valid? method" do
      schema = JsonSchemer.schema(%q({"type": "string"}))

      # Should not raise error when passing resolve_enumerators to valid?
      schema.valid?(JSON::Any.new("hello"), resolve_enumerators: true).should be_true
      schema.valid?(JSON::Any.new("hello"), resolve_enumerators: false).should be_true
    end

    it "validates normally regardless of resolve_enumerators setting" do
      schema_with_true = JsonSchemer.schema(
        %q({"type": "integer", "minimum": 0}),
        resolve_enumerators: true
      )

      schema_with_false = JsonSchemer.schema(
        %q({"type": "integer", "minimum": 0}),
        resolve_enumerators: false
      )

      # Both should validate the same way
      schema_with_true.valid?(JSON::Any.new(5_i64)).should be_true
      schema_with_true.valid?(JSON::Any.new(-1_i64)).should be_false

      schema_with_false.valid?(JSON::Any.new(5_i64)).should be_true
      schema_with_false.valid?(JSON::Any.new(-1_i64)).should be_false
    end
  end

  describe "global configuration" do
    it "accepts keywords in global configuration" do
      # Store original to restore later
      original_keywords = JsonSchemer.configuration.keywords.dup

      begin
        JsonSchemer.configure do |config|
          config.keywords["x-global"] = ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
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

    it "accepts resolve_enumerators in global configuration" do
      original = JsonSchemer.configuration.resolve_enumerators

      begin
        JsonSchemer.configure do |config|
          config.resolve_enumerators = true
        end

        JsonSchemer.configuration.resolve_enumerators.should be_true
      ensure
        JsonSchemer.configuration.resolve_enumerators = original
      end
    end
  end
end
