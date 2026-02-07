require "./spec_helper"
require "big"

module CustomKeywords
  class MoneyKeyword < JsonSchemer::Keyword
    @min : BigDecimal
    @max : BigDecimal

    def initialize(value : JSON::Any, parent : JsonSchemer::Schema | JsonSchemer::Keyword, keyword : String, schema : JsonSchemer::Schema? = nil)
      @min = BigDecimal.new(-1)
      @max = BigDecimal.new("999999999999999999999999") # A sufficiently large number
      super
    end

    def parse : JSON::Any | JsonSchemer::Schema | Array(JsonSchemer::Schema) | Hash(String, JsonSchemer::Schema) | Hash(String, JsonSchemer::Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
      unless value.raw.is_a?(Hash)
        raise JsonSchemer::InvalidSchema.new("Value for keyword 'money' must be an object")
      end

      hash = value.as_h

      if min_val = hash["minimum"]?
        if min_str = min_val.as_s?
          @min = BigDecimal.new(min_str)
        else
          raise JsonSchemer::InvalidSchema.new("Value for 'minimum' in 'money' keyword must be a string")
        end
      end

      if max_val = hash["maximum"]?
        if max_str = max_val.as_s?
          @max = BigDecimal.new(max_str)
        else
          raise JsonSchemer::InvalidSchema.new("Value for 'maximum' in 'money' keyword must be a string")
        end
      end

      if @min < -1
        raise JsonSchemer::InvalidSchema.new("Value for 'minimum' in 'money' keyword must be non-negative")
      end
      # If user explicitly set min < 0, but since @min default is -1, checking < -1 means checking if user set it to something < -1.
      # Wait, if user sets "minimum": -5, then @min becomes -5. -5 < -1 is true.
      # So if user provides ANY negative number, it's < -1? No. -0.5 is > -1.
      # The user said "raise an error if ... negative".
      # Default is -1.
      # If user provides -5, it is negative.
      # If user provides nothing, it is -1.
      # I need to distinguish "user provided" vs "default".
      # Or, I change default to be -1, and enforce user provided >= 0.
      # If @min is -1 (default), it is negative, but that's allowed as internal state for "no limit".
      # But if user provides -5, it becomes -5.
      # So: if hash["minimum"]? && @min < 0 -> Error.
      # But wait, logic:

      if hash.has_key?("minimum") && @min < 0
        raise JsonSchemer::InvalidSchema.new("Value for 'minimum' in 'money' keyword must be non-negative")
      end

      if hash.has_key?("maximum") && @max < 0
        raise JsonSchemer::InvalidSchema.new("Value for 'maximum' in 'money' keyword must be non-negative")
      end

      if @min > @max
        raise JsonSchemer::InvalidSchema.new("Value for 'minimum' cannot be greater than 'maximum' in 'money' keyword")
      end

      value
    end

    def validate(instance, instance_location, keyword_location, context)
      # Only validate strings
      unless instance.raw.is_a?(String)
        return result(instance, instance_location, keyword_location, true)
      end

      val_str = instance.as_s
      # Simple regex for money: "12.34"
      unless val_str.matches?(/\A\d+\.\d{2}\z/)
        return result(instance, instance_location, keyword_location, false)
      end

      amount = BigDecimal.new(val_str)

      # Check min if it's set (i.e. not default -1)
      # Actually, since money is always positive (>= 0), and default is -1.
      # If amount is valid money (>= 0), it is always > -1.
      # So we can just check `amount < @min`.
      # Example: amount = 10. @min = -1. 10 < -1 is false. OK.
      # Example: amount = 10. @min = 20. 10 < 20 is true. Error. OK.
      if amount < @min
        return result(instance, instance_location, keyword_location, false,
          details: {"error" => JSON::Any.new("amount must be >= #{@min}")}
        )
      end

      if amount > @max
        return result(instance, instance_location, keyword_location, false,
          details: {"error" => JSON::Any.new("amount must be <= #{@max}")}
        )
      end

      result(instance, instance_location, keyword_location, true)
    end

    def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
      if details && (msg = details["error"]?)
        "value at #{formatted_instance_location} is invalid: #{msg.as_s}"
      else
        "value at #{formatted_instance_location} is not a valid money amount (e.g. 12.34)"
      end
    end
  end
end

describe "Custom Keyword Class with Parse" do
  it "validates using a registered custom keyword class with constraints" do
    JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"]["money"] = CustomKeywords::MoneyKeyword

    begin
      schema_json = %q({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary": {
          "https://json-schema.org/draft/2020-12/vocab/core": true,
          "https://json-schema.org/draft/2020-12/vocab/applicator": true,
          "https://json-schema.org/draft/2020-12/vocab/validation": true,
          "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
          "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
          "https://json-schema.org/draft/2020-12/vocab/content": true,
          "https://json-schema.org/draft/2020-12/vocab/unevaluated": true
        },
        "type": "string",
        "money": {
          "minimum": "10.00",
          "maximum": "100.00"
        }
      })

      schema = JsonSchemer.schema(schema_json)

      # Valid case
      schema.valid?(JSON::Any.new("12.34")).should be_true
      schema.valid?(JSON::Any.new("100.00")).should be_true
      schema.valid?(JSON::Any.new("10.00")).should be_true

      # Invalid format
      schema.valid?(JSON::Any.new("12")).should be_false
      schema.valid?(JSON::Any.new("abc")).should be_false

      # Out of bounds
      schema.valid?(JSON::Any.new("9.99")).should be_false
      schema.valid?(JSON::Any.new("100.01")).should be_false

      # Check error message for bounds
      result = schema.validate(JSON::Any.new("9.99"))
      errors = get_errors(result)
      errors.size.should eq(1)
      errors.first["error"].as_s.should contain("amount must be >=")

      result_max = schema.validate(JSON::Any.new("100.01"))
      errors_max = get_errors(result_max)
      errors_max.size.should eq(1)
      errors_max.first["error"].as_s.should contain("amount must be <=")
    ensure
      # Cleanup
      JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"].delete("money")
    end
  end

  it "raises invalid schema error if keyword value is not an object" do
    JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"]["money"] = CustomKeywords::MoneyKeyword

    begin
      schema_json = %q({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary": {
          "https://json-schema.org/draft/2020-12/vocab/validation": true
        },
        "money": true
      })

      expect_raises(JsonSchemer::InvalidSchema, "Value for keyword 'money' must be an object") do
        JsonSchemer.schema(schema_json)
      end
    ensure
      JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"].delete("money")
    end
  end

  it "raises invalid schema error if minimum is negative" do
    JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"]["money"] = CustomKeywords::MoneyKeyword

    begin
      schema_json = %q({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary": {
          "https://json-schema.org/draft/2020-12/vocab/validation": true
        },
        "money": {
          "minimum": "-5"
        }
      })

      expect_raises(JsonSchemer::InvalidSchema, "Value for 'minimum' in 'money' keyword must be non-negative") do
        JsonSchemer.schema(schema_json)
      end
    ensure
      JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"].delete("money")
    end
  end

  it "raises invalid schema error if min > max" do
    JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"]["money"] = CustomKeywords::MoneyKeyword

    begin
      schema_json = %q({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary": {
          "https://json-schema.org/draft/2020-12/vocab/validation": true
        },
        "money": {
          "minimum": "20",
          "maximum": "10"
        }
      })

      expect_raises(JsonSchemer::InvalidSchema, "Value for 'minimum' cannot be greater than 'maximum' in 'money' keyword") do
        JsonSchemer.schema(schema_json)
      end
    ensure
      JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"].delete("money")
    end
  end

  it "raises invalid schema error if minimum is not a string" do
    JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"]["money"] = CustomKeywords::MoneyKeyword

    begin
      schema_json = %q({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary": {
          "https://json-schema.org/draft/2020-12/vocab/validation": true
        },
        "money": {
          "minimum": 10.00
        }
      })

      expect_raises(JsonSchemer::InvalidSchema, "Value for 'minimum' in 'money' keyword must be a string") do
        JsonSchemer.schema(schema_json)
      end
    ensure
      JsonSchemer::VOCABULARIES["https://json-schema.org/draft/2020-12/vocab/validation"].delete("money")
    end
  end
end
