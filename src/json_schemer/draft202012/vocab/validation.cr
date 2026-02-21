module JsonSchemer
  module Draft202012
    module Vocab
      module Validation
        # Shared logic for integer limit keywords
        module ParseIntLimit
          def parse_int_limit(keyword_name : String) : Int64
            raw = value.raw
            if raw.is_a?(Int64)
              raw
            elsif raw.is_a?(Float64)
              if raw == raw.floor
                raw.to_i64
              else
                raise InvalidSchema.new("Value for keyword '#{keyword_name}' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword '#{keyword_name}' must be a number")
            end
          end
        end

        # Base class for numeric limit keywords
        abstract class NumericLimit < Keyword
          @limit : BigDecimal = BigDecimal.new(0)

          abstract def compare(value : BigDecimal, limit : BigDecimal) : Bool
          abstract def limit_name : String
          abstract def error_message_relation : String

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is #{error_message_relation}: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            unless value.raw.is_a?(Number)
              raise InvalidSchema.new("Value for keyword '#{limit_name}' must be a number")
            end
            @limit = BigDecimal.new(value.raw.as(Number).to_s)
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, location, true)
            end
            valid = compare(BigDecimal.new(instance.raw.as(Number).to_s), @limit)
            result(instance, instance_location, location, valid)
          end
        end

        # Type keyword
        class Type < Keyword
          @types : Array(String) = [] of String
          @single_type : String?

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

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            if value.raw.is_a?(Array)
              @types = value.as_a.map(&.as_s)
              @types
            else
              @single_type = value.as_s
              value
            end
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            if single = @single_type
              valid = valid_type(single, instance)
              result(instance, instance_location, location, valid, type: single)
            else
              # Use types array (even if empty, though empty type array is probably invalid schema or matches nothing)
              valid = @types.any? { |type_str| valid_type(type_str, instance) }
              result(instance, instance_location, location, valid)
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
          @enum_values : Array(JSON::Any) = [] of JSON::Any
          @enum_set : Set(JSON::Any)?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} is not one of: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            # Enum value must be an array
            if value.raw.is_a?(Array)
              @enum_values = value.as_a
              # Optimization: Use Set for large enums (threshold > 10)
              if @enum_values.size > 10
                @enum_set = Set(JSON::Any).new(@enum_values)
              end
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            if @enum_values.empty? && !value.raw.is_a?(Array)
              # If value is not an array, we ignore validation
              result(instance, instance_location, location, true)
            else
              valid = if set = @enum_set
                        set.includes?(instance)
                      else
                        @enum_values.includes?(instance)
                      end
              result(instance, instance_location, location, valid)
            end
          end
        end

        # Const keyword
        class Const < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} is not: #{value}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            result(instance, instance_location, location, value == instance)
          end
        end

        # MultipleOf keyword
        class MultipleOf < Keyword
          # Default value 1 is safe - parse validates and sets the actual value
          @multiple_of_value : BigDecimal = BigDecimal.new(1)

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is not a multiple of: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            unless value.raw.is_a?(Number)
              raise InvalidSchema.new("Value for keyword 'multipleOf' must be a number")
            end
            # Potential issue of losing precision when converting to BigDecimal
            @multiple_of_value = BigDecimal.new(value.raw.as(Number).to_s)
            if @multiple_of_value <= BigDecimal.new(0)
              raise InvalidSchema.new("Value for keyword 'multipleOf' must be strictly greater than 0")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, location, true)
            end

            instance_bd = BigDecimal.new(instance.raw.as(Number).to_s)
            valid = (instance_bd % @multiple_of_value).zero?
            result(instance, instance_location, location, valid)
          end
        end

        # Maximum keyword
        class Maximum < NumericLimit
          def compare(value : BigDecimal, limit : BigDecimal) : Bool
            value <= limit
          end

          def limit_name : String
            "maximum"
          end

          def error_message_relation : String
            "greater than"
          end
        end

        # ExclusiveMaximum keyword
        class ExclusiveMaximum < NumericLimit
          def compare(value : BigDecimal, limit : BigDecimal) : Bool
            value < limit
          end

          def limit_name : String
            "exclusiveMaximum"
          end

          def error_message_relation : String
            "greater than or equal to"
          end
        end

        # Minimum keyword
        class Minimum < NumericLimit
          def compare(value : BigDecimal, limit : BigDecimal) : Bool
            value >= limit
          end

          def limit_name : String
            "minimum"
          end

          def error_message_relation : String
            "less than"
          end
        end

        # ExclusiveMinimum keyword
        class ExclusiveMinimum < NumericLimit
          def compare(value : BigDecimal, limit : BigDecimal) : Bool
            value > limit
          end

          def limit_name : String
            "exclusiveMinimum"
          end

          def error_message_relation : String
            "less than or equal to"
          end
        end

        # MaxLength keyword
        class MaxLength < Keyword
          include ParseIntLimit
          @max_length : Int64 = Int64::MAX

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "string length at #{formatted_instance_location} is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @max_length = parse_int_limit("maxLength")
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, location, true)
            end
            valid = instance.as_s.size <= @max_length
            result(instance, instance_location, location, valid)
          end
        end

        # MinLength keyword
        class MinLength < Keyword
          include ParseIntLimit
          @min_length : Int64 = 0

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "string length at #{formatted_instance_location} is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @min_length = parse_int_limit("minLength")
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, location, true)
            end
            valid = instance.as_s.size >= @min_length
            result(instance, instance_location, location, valid)
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

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, location, true)
            end
            regex = @regex
            return result(instance, instance_location, location, true) unless regex
            valid = regex.matches?(instance.as_s)
            result(instance, instance_location, location, valid)
          end
        end

        # MaxItems keyword
        class MaxItems < Keyword
          include ParseIntLimit
          @max_items : Int64 = Int64::MAX

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array size at #{formatted_instance_location} is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @max_items = parse_int_limit("maxItems")
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, location, true)
            end
            valid = instance.as_a.size <= @max_items
            result(instance, instance_location, location, valid)
          end
        end

        # MinItems keyword
        class MinItems < Keyword
          include ParseIntLimit
          @min_items : Int64 = 0

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array size at #{formatted_instance_location} is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @min_items = parse_int_limit("minItems")
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, location, true)
            end
            valid = instance.as_a.size >= @min_items
            result(instance, instance_location, location, valid)
          end
        end

        # UniqueItems keyword
        class UniqueItems < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array items at #{formatted_instance_location} are not unique"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, location, true)
            end
            if value.as_bool == false
              return result(instance, instance_location, location, true)
            end

            arr = instance.as_a
            return result(instance, instance_location, location, true) if arr.size <= 1

            # Optimization: Use Set iteration to short-circuit on first duplicate
            seen = Set(JSON::Any).new(initial_capacity: arr.size)
            valid = arr.all? { |item| seen.add?(item) }

            result(instance, instance_location, location, valid)
          end
        end

        # MaxContains keyword
        class MaxContains < Keyword
          include ParseIntLimit
          @max_contains : Int64 = Int64::MAX

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number of array items at #{formatted_instance_location} matching `contains` schema is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @max_contains = parse_int_limit("maxContains")
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, location, true)
            end
            contains_result = context.adjacent_results.try(&.[Applicator::Contains]?)
            unless contains_result
              return result(instance, instance_location, location, true)
            end
            anno = contains_result.annotation
            if anno && anno.raw.is_a?(Array)
              valid = anno.as_a.size <= @max_contains
              result(instance, instance_location, location, valid)
            else
              result(instance, instance_location, location, true)
            end
          end
        end

        # MinContains keyword
        class MinContains < Keyword
          include ParseIntLimit
          @min_contains : Int64 = 0

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number of array items at #{formatted_instance_location} matching `contains` schema is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @min_contains = parse_int_limit("minContains")
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, location, true)
            end
            contains_result = context.adjacent_results.try(&.[Applicator::Contains]?)
            unless contains_result
              return result(instance, instance_location, location, true)
            end
            anno = contains_result.annotation
            if anno && anno.raw.is_a?(Array)
              valid = anno.as_a.size >= @min_contains
              result(instance, instance_location, location, valid)
            else
              result(instance, instance_location, location, true)
            end
          end
        end

        # MaxProperties keyword
        class MaxProperties < Keyword
          include ParseIntLimit
          @max_properties : Int64 = Int64::MAX

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object size at #{formatted_instance_location} is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @max_properties = parse_int_limit("maxProperties")
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end
            valid = instance.as_h.size <= @max_properties
            result(instance, instance_location, location, valid)
          end
        end

        # MinProperties keyword
        class MinProperties < Keyword
          include ParseIntLimit
          @min_properties : Int64 = 0

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object size at #{formatted_instance_location} is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @min_properties = parse_int_limit("minProperties")
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end
            valid = instance.as_h.size >= @min_properties
            result(instance, instance_location, location, valid)
          end
        end

        # Required keyword
        class Required < Keyword
          @required_keys : Array(String) = [] of String
          @effective_keys_read : (Array(String) | Nil) = nil
          @effective_keys_write : (Array(String) | Nil) = nil

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            missing = details.try(&.["missing_keys"]?.try(&.as_a.map(&.as_s).join(", "))) || ""
            "object at #{formatted_instance_location} is missing required properties: #{missing}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @required_keys = value.as_a.map(&.as_s)
            @required_keys
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end

            effective_required_keys = case context.access_mode
                                      when "read"
                                        if @effective_keys_read.nil?
                                          @effective_keys_read = calculate_effective_keys("read")
                                        end
                                        @effective_keys_read.not_nil!
                                      when "write"
                                        if @effective_keys_write.nil?
                                          @effective_keys_write = calculate_effective_keys("write")
                                        end
                                        @effective_keys_write.not_nil!
                                      else
                                        @required_keys
                                      end

            valid = effective_required_keys.all? { |k| instance.as_h.has_key?(k) }
            if valid
              result(instance, instance_location, location, true)
            else
              missing_keys = effective_required_keys.reject { |k| instance.as_h.has_key?(k) }
              details_hash = {"missing_keys" => JSON::Any.new(missing_keys.map { |k| JSON::Any.new(k) })}
              result(instance, instance_location, location, false, details: details_hash)
            end
          end

          private def calculate_effective_keys(mode : String) : Array(String)
            inapplicable = [] of String

            queue = Deque(Schema).new
            queue << schema
            visited = Set(Schema).new

            while !queue.empty?
              s = queue.shift
              next if visited.includes?(s)
              visited << s

              # Use _keywords_lock if necessary, but here we just read parsed
              properties_kw = s.parsed.try(&.["properties"]?)
              if properties_kw.is_a?(Keyword) && properties_kw.parsed.is_a?(Hash(String, Schema))
                properties_kw.parsed.as(Hash(String, Schema)).each do |property, subschema|
                  read_only = subschema.parsed.try(&.["readOnly"]?)
                  write_only = subschema.parsed.try(&.["writeOnly"]?)

                  if mode == "write" && read_only.try(&.value.as_bool?) == true
                    inapplicable << property
                  end
                  if mode == "read" && write_only.try(&.value.as_bool?) == true
                    inapplicable << property
                  end
                end
              end

              if ref_kw = s.parsed.try(&.["$ref"]?)
                if ref_kw.is_a?(Draft202012::Vocab::Core::Ref)
                  begin
                    queue << ref_kw.ref_schema
                  rescue InvalidRefResolution | InvalidRefPointer | UnknownRef
                    # Skip unresolvable refs during access mode calculation
                  end
                end
              end

              {"allOf", "anyOf", "oneOf"}.each do |applicator_key|
                if app_kw = s.parsed.try(&.[applicator_key]?)
                  if app_kw.is_a?(Keyword) && app_kw.parsed.is_a?(Array(Schema))
                    app_kw.parsed.as(Array(Schema)).each { |sub| queue << sub }
                  end
                end
              end
            end

            inapplicable.empty? ? @required_keys : @required_keys.reject { |k| inapplicable.includes?(k) }
          end

          def after_schema_initialize : Nil
            # Deferred to lazy initialization during validation
            # to avoid $ref resolution cycles during schema parsing
          end
        end

        # DependentRequired keyword
        class DependentRequired < Keyword
          @dependent_required : Hash(String, Array(String)) = {} of String => Array(String)

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object at #{formatted_instance_location} is missing required `dependentRequired` properties"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            result = {} of String => Array(String)
            value.as_h.each do |key, required_keys|
              result[key] = required_keys.as_a.map(&.as_s)
            end
            @dependent_required = result
            result
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end

            existing_keys = instance.as_h
            nested = [] of Result

            @dependent_required.each do |key, required|
              next unless existing_keys.has_key?(key)

              valid = required.all? { |k| existing_keys.has_key?(k) }
              unless valid
                missing = required.reject { |k| existing_keys.has_key?(k) }
                nested << result(
                  instance,
                  join_location(instance_location, key),
                  join_location(location, key),
                  false,
                  details: {"missing_keys" => JSON::Any.new(missing.map { |k| JSON::Any.new(k) })}
                )
              end
            end

            result(instance, instance_location, location, nested.empty?, nested)
          end
        end
      end
    end
  end
end
