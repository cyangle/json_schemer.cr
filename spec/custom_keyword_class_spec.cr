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

    def validate(instance, instance_location, context)
      unless instance.raw.is_a?(String)
        return result(instance, instance_location, location, true)
      end

      val_str = instance.as_s
      unless val_str.matches?(/\A\d+\.\d{2}\z/)
        return result(instance, instance_location, location, false)
      end

      amount = BigDecimal.new(val_str)

      if amount < @min
        return result(instance, instance_location, location, false,
          details: {"error" => JSON::Any.new("amount must be >= #{@min}")}
        )
      end

      if amount > @max
        return result(instance, instance_location, location, false,
          details: {"error" => JSON::Any.new("amount must be <= #{@max}")}
        )
      end

      result(instance, instance_location, location, true)
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

describe "Custom Keyword Class with Vocabulary" do
  it "validates using a custom meta-schema defining a new vocabulary" do
    JsonSchemer::VOCABULARIES["https://example.com/vocab/money"] = {
      "money" => CustomKeywords::MoneyKeyword.as(JsonSchemer::Keyword.class),
    } of String => JsonSchemer::Keyword.class
    JsonSchemer::VOCABULARY_ORDER["https://example.com/vocab/money"] = 100

    begin
      meta_json = {
        "$id"         => "https://example.com/meta",
        "$schema"     => "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary" => {
          "https://json-schema.org/draft/2020-12/vocab/core"       => true,
          "https://json-schema.org/draft/2020-12/vocab/validation" => true,
          "https://example.com/vocab/money"                        => true,
        },
      }

      # Use a custom resolver to provide the meta-schema
      resolver = ->(uri : URI) {
        if uri.to_s == "https://example.com/meta"
          JSON.parse(meta_json.to_json).as_h
        else
          nil.as(JsonSchemer::JSONHash?)
        end
      }

      schema_json = %q({
        "$schema": "https://example.com/meta",
        "type": "string",
        "money": {
          "minimum": "10.00",
          "maximum": "100.00"
        }
      })

      schema = JsonSchemer.schema(schema_json, ref_resolver: resolver)

      # Valid cases
      schema.valid?(JSON::Any.new("12.34")).should be_true
      schema.valid?(JSON::Any.new("100.00")).should be_true
      schema.valid?(JSON::Any.new("10.00")).should be_true

      # Invalid format
      schema.valid?(JSON::Any.new("12")).should be_false

      # Out of bounds
      schema.valid?(JSON::Any.new("9.99")).should be_false
    ensure
      JsonSchemer::VOCABULARIES.delete("https://example.com/vocab/money")
      JsonSchemer::VOCABULARY_ORDER.delete("https://example.com/vocab/money")
    end
  end

  it "raises invalid schema error if keyword value is not an object" do
    JsonSchemer::VOCABULARIES["https://example.com/vocab/money"] = {
      "money" => CustomKeywords::MoneyKeyword.as(JsonSchemer::Keyword.class),
    } of String => JsonSchemer::Keyword.class

    begin
      meta_json = {
        "$id"         => "https://example.com/meta",
        "$schema"     => "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary" => {
          "https://example.com/vocab/money" => true,
        },
      }

      resolver = ->(uri : URI) {
        uri.to_s == "https://example.com/meta" ? JSON.parse(meta_json.to_json).as_h : nil.as(JsonSchemer::JSONHash?)
      }

      schema_json = %q({
        "$schema": "https://example.com/meta",
        "money": true
      })

      expect_raises(JsonSchemer::InvalidSchema, "Value for keyword 'money' must be an object") do
        JsonSchemer.schema(schema_json, ref_resolver: resolver)
      end
    ensure
      JsonSchemer::VOCABULARIES.delete("https://example.com/vocab/money")
    end
  end
end
