module JsonSchemer
  module Draft202012
    module Vocab
      module Validation
        # Type keyword
        class Type < Keyword
          def self.valid_integer?(instance : JSON::Any) : Bool
            case instance.raw
            when Int64
              true
            when Float64
              instance.as_f.floor == instance.as_f
            else
              false
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            v = value.as_s? || value.as_a?.try(&.map(&.as_s).join(", "))
            case v
            when "null"
              "value at #{formatted_instance_location} is not null"
            when "boolean"
              "value at #{formatted_instance_location} is not a boolean"
            when "number"
              "value at #{formatted_instance_location} is not a number"
            when "integer"
              "value at #{formatted_instance_location} is not an integer"
            when "string"
              "value at #{formatted_instance_location} is not a string"
            when "array"
              "value at #{formatted_instance_location} is not an array"
            when "object"
              "value at #{formatted_instance_location} is not an object"
            else
              "value at #{formatted_instance_location} is not one of the types: #{v}"
            end
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            case value.raw
            when String
              valid = valid_type(value.as_s, instance)
              result(instance, instance_location, keyword_location, valid, type: value.as_s)
            when Array
              valid = value.as_a.any? { |t| valid_type(t.as_s, instance) }
              result(instance, instance_location, keyword_location, valid)
            else
              result(instance, instance_location, keyword_location, true)
            end
          end

          private def valid_type(type : String, instance : JSON::Any) : Bool
            case type
            when "null"
              instance.raw.nil?
            when "boolean"
              instance.raw == true || instance.raw == false
            when "number"
              instance.raw.is_a?(Number)
            when "integer"
              Type.valid_integer?(instance)
            when "string"
              instance.raw.is_a?(String)
            when "array"
              instance.raw.is_a?(Array)
            when "object"
              instance.raw.is_a?(Hash)
            else
              true
            end
          end
        end

        # Enum keyword
        class Enum < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} is not one of: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            if value.raw.nil?
              result(instance, instance_location, keyword_location, true)
            else
              valid = value.as_a.includes?(instance)
              result(instance, instance_location, keyword_location, valid)
            end
          end
        end

        # Const keyword
        class Const < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} is not: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            result(instance, instance_location, keyword_location, value == instance)
          end
        end

        # MultipleOf keyword
        class MultipleOf < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is not a multiple of: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end

            instance_bd = BigDecimal.new(instance.raw.as(Number).to_s)
            value_bd = BigDecimal.new(value.raw.as(Number).to_s)
            valid = (instance_bd % value_bd).zero?
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # Maximum keyword
        class Maximum < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is greater than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = compare_numbers(instance.raw.as(Number), value.raw.as(Number)) <= 0
            result(instance, instance_location, keyword_location, valid)
          end

          private def compare_numbers(a : Number, b : Number) : Int32
            (a.to_f64 <=> b.to_f64) || 0
          end
        end

        # ExclusiveMaximum keyword
        class ExclusiveMaximum < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is greater than or equal to: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.raw.as(Number).to_f64 < value.raw.as(Number).to_f64
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # Minimum keyword
        class Minimum < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is less than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.raw.as(Number).to_f64 >= value.raw.as(Number).to_f64
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # ExclusiveMinimum keyword
        class ExclusiveMinimum < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is less than or equal to: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.raw.as(Number).to_f64 > value.raw.as(Number).to_f64
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MaxLength keyword
        class MaxLength < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "string length at #{formatted_instance_location} is greater than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_s.size <= (value.as_i? || value.as_f).to_i
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MinLength keyword
        class MinLength < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "string length at #{formatted_instance_location} is less than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_s.size >= (value.as_i? || value.as_f).to_i
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # Pattern keyword
        class Pattern < Keyword
          @regex : Regex?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "string at #{formatted_instance_location} does not match pattern: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @regex = root.resolve_regexp(value.as_s)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = @regex.not_nil!.matches?(instance.as_s)
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MaxItems keyword
        class MaxItems < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array size at #{formatted_instance_location} is greater than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_a.size <= (value.as_i? || value.as_f).to_i
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MinItems keyword
        class MinItems < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array size at #{formatted_instance_location} is less than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_a.size >= (value.as_i? || value.as_f).to_i
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # UniqueItems keyword
        class UniqueItems < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array items at #{formatted_instance_location} are not unique"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            if value.as_bool == false
              return result(instance, instance_location, keyword_location, true)
            end
            arr = instance.as_a
            valid = arr.size == arr.uniq.size
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MaxContains keyword
        class MaxContains < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number of array items at #{formatted_instance_location} matching `contains` schema is greater than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            contains_result = context.adjacent_results[Applicator::Contains]?
            unless contains_result
              return result(instance, instance_location, keyword_location, true)
            end
            anno = contains_result.get_annotation
            if anno && anno.raw.is_a?(Array)
              valid = anno.as_a.size <= (value.as_i? || value.as_f).to_i
              result(instance, instance_location, keyword_location, valid)
            else
              result(instance, instance_location, keyword_location, true)
            end
          end
        end

        # MinContains keyword
        class MinContains < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number of array items at #{formatted_instance_location} matching `contains` schema is less than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            contains_result = context.adjacent_results[Applicator::Contains]?
            unless contains_result
              return result(instance, instance_location, keyword_location, true)
            end
            anno = contains_result.get_annotation
            if anno && anno.raw.is_a?(Array)
              valid = anno.as_a.size >= (value.as_i? || value.as_f).to_i
              result(instance, instance_location, keyword_location, valid)
            else
              result(instance, instance_location, keyword_location, true)
            end
          end
        end

        # MaxProperties keyword
        class MaxProperties < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object size at #{formatted_instance_location} is greater than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_h.size <= (value.as_i? || value.as_f).to_i
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MinProperties keyword
        class MinProperties < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object size at #{formatted_instance_location} is less than: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_h.size >= (value.as_i? || value.as_f).to_i
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # Required keyword
        class Required < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            missing = details.try(&.["missing_keys"]?.try(&.as_a.map(&.as_s).join(", "))) || ""
            "object at #{formatted_instance_location} is missing required properties: #{missing}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            required_keys = value.as_a.map(&.as_s)
            instance_keys = instance.as_h.keys

            # Handle access mode
            if context.access_mode
              properties_kw = schema.parsed["properties"]?
              if properties_kw.is_a?(Keyword) && properties_kw.parsed.is_a?(Hash(String, Schema))
                inapplicable = [] of String
                properties_kw.parsed.as(Hash(String, Schema)).each do |property, subschema|
                  read_only = subschema.parsed["readOnly"]?
                  write_only = subschema.parsed["writeOnly"]?

                  if context.access_mode == "write" && read_only.try(&.value.as_bool?) == true
                    inapplicable << property
                  end
                  if context.access_mode == "read" && write_only.try(&.value.as_bool?) == true
                    inapplicable << property
                  end
                end
                required_keys = required_keys - inapplicable
              end
            end

            missing_keys = required_keys - instance_keys
            details_hash = {"missing_keys" => JSON::Any.new(missing_keys.map { |k| JSON::Any.new(k) })}
            result(instance, instance_location, keyword_location, missing_keys.empty?, details: details_hash)
          end
        end

        # DependentRequired keyword
        class DependentRequired < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object at #{formatted_instance_location} is missing required `dependentRequired` properties"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            existing_keys = instance.as_h.keys
            nested = [] of Result

            value.as_h.each do |key, required_keys|
              next unless instance.as_h.has_key?(key)

              required = required_keys.as_a.map(&.as_s)
              missing = required - existing_keys
              nested << result(
                instance,
                join_location(instance_location, key),
                join_location(keyword_location, key),
                missing.empty?
              )
            end

            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested)
          end
        end
      end
    end
  end
end
