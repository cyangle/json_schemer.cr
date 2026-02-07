module JsonSchemer
  module Draft202012
    module Vocab
      module Validation
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

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            if single = @single_type
              valid = valid_type(single, instance)
              result(instance, instance_location, keyword_location, valid, type: single)
            else
              # Use types array (even if empty, though empty type array is probably invalid schema or matches nothing)
              valid = @types.any? { |t| valid_type(t, instance) }
              result(instance, instance_location, keyword_location, valid)
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

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} is not one of: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            # Enum value must be an array
            if value.raw.is_a?(Array)
              @enum_values = value.as_a
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            if @enum_values.empty? && !value.raw.is_a?(Array)
              # If value is not an array, we ignore validation (consistent with previous behavior)
              # But wait, if it IS an empty array [], validation should fail for any instance.
              # So we need to distinguish empty array vs not-array.
              # But previously: if value.raw.is_a?(Array) -> @enum_values set.
              # If @enum_values is nil (not array), return true.
              # If I want to avoid nilable, I need to know if it was set.
              result(instance, instance_location, keyword_location, true)
            else
              valid = @enum_values.includes?(instance)
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
          @multiple_of_value : BigDecimal

          def initialize(value : JSON::Any, parent : Schema | Keyword, keyword : String, schema : Schema? = nil)
            super
            if val = value.raw
              if val.is_a?(Number)
                @multiple_of_value = BigDecimal.new(val.to_s)
              else
                # Should be unreachable if parse raises, but compiler needs it
                @multiple_of_value = BigDecimal.new("0")
              end
            else
              @multiple_of_value = BigDecimal.new("0")
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is not a multiple of: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            unless value.raw.is_a?(Number)
              raise InvalidSchema.new("Value for keyword 'multipleOf' must be a number")
            end
            # @multiple_of_value is set in initialize or here?
            # Parse is called in initialize. But Crystal compiler complains if not set in initialize.
            # We must set it in parse but compiler doesn't know parse is called in initialize?
            # Actually parse IS called in initialize.
            # But compiler needs guarantee.
            @multiple_of_value = BigDecimal.new(value.raw.as(Number).to_s)
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end

            instance_bd = BigDecimal.new(instance.raw.as(Number).to_s)
            valid = (instance_bd % @multiple_of_value).zero?
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # Maximum keyword
        class Maximum < Keyword
          @max_value : Float64

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            if val = value.raw.as?(Number)
              @max_value = val.to_f64
            else
              @max_value = 0.0
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            unless value.raw.is_a?(Number)
              raise InvalidSchema.new("Value for keyword 'maximum' must be a number")
            end
            @max_value = value.raw.as(Number).to_f64
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.raw.as(Number).to_f64 <= @max_value
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # ExclusiveMaximum keyword
        class ExclusiveMaximum < Keyword
          @ex_max_value : Float64

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            if val = value.raw.as?(Number)
              @ex_max_value = val.to_f64
            else
              # raise error instead of fallback, but compiler needs assignment
              @ex_max_value = 0.0
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is greater than or equal to: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            unless value.raw.is_a?(Number)
              raise InvalidSchema.new("Value for keyword 'exclusiveMaximum' must be a number")
            end
            @ex_max_value = value.raw.as(Number).to_f64
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.raw.as(Number).to_f64 < @ex_max_value
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # Minimum keyword
        class Minimum < Keyword
          @min_value : Float64

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            if val = value.raw.as?(Number)
              @min_value = val.to_f64
            else
              @min_value = 0.0
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            unless value.raw.is_a?(Number)
              raise InvalidSchema.new("Value for keyword 'minimum' must be a number")
            end
            @min_value = value.raw.as(Number).to_f64
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.raw.as(Number).to_f64 >= @min_value
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # ExclusiveMinimum keyword
        class ExclusiveMinimum < Keyword
          @ex_min_value : Float64

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            if val = value.raw.as?(Number)
              @ex_min_value = val.to_f64
            else
              @ex_min_value = 0.0
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number at #{formatted_instance_location} is less than or equal to: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            unless value.raw.is_a?(Number)
              raise InvalidSchema.new("Value for keyword 'exclusiveMinimum' must be a number")
            end
            @ex_min_value = value.raw.as(Number).to_f64
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Number)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.raw.as(Number).to_f64 > @ex_min_value
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MaxLength keyword
        class MaxLength < Keyword
          @max_length : Int32

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            # Pre-initialize with safe defaults to satisfy compiler
            @max_length = 0
            if val = value.raw.as?(Int)
              @max_length = val.to_i
            elsif val = value.raw.as?(Float)
              @max_length = val.to_i
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "string length at #{formatted_instance_location} is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            raw = value.raw
            if raw.is_a?(Int)
              @max_length = raw.to_i
            elsif raw.is_a?(Float)
              if raw == raw.floor
                @max_length = raw.to_i
              else
                raise InvalidSchema.new("Value for keyword 'maxLength' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword 'maxLength' must be a number")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_s.size <= @max_length
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MinLength keyword
        class MinLength < Keyword
          @min_length : Int32

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            @min_length = 0
            if val = value.raw.as?(Int)
              @min_length = val.to_i
            elsif val = value.raw.as?(Float)
              @min_length = val.to_i
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "string length at #{formatted_instance_location} is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            raw = value.raw
            if raw.is_a?(Int)
              @min_length = raw.to_i
            elsif raw.is_a?(Float)
              if raw == raw.floor
                @min_length = raw.to_i
              else
                raise InvalidSchema.new("Value for keyword 'minLength' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword 'minLength' must be a number")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_s.size >= @min_length
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
          @max_items : Int32

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            @max_items = 0
            if val = value.raw.as?(Int)
              @max_items = val.to_i
            elsif val = value.raw.as?(Float)
              @max_items = val.to_i
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array size at #{formatted_instance_location} is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            raw = value.raw
            if raw.is_a?(Int)
              @max_items = raw.to_i
            elsif raw.is_a?(Float)
              if raw == raw.floor
                @max_items = raw.to_i
              else
                raise InvalidSchema.new("Value for keyword 'maxItems' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword 'maxItems' must be a number")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_a.size <= @max_items
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MinItems keyword
        class MinItems < Keyword
          @min_items : Int32

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            @min_items = 0
            if val = value.raw.as?(Int)
              @min_items = val.to_i
            elsif val = value.raw.as?(Float)
              @min_items = val.to_i
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array size at #{formatted_instance_location} is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            raw = value.raw
            if raw.is_a?(Int)
              @min_items = raw.to_i
            elsif raw.is_a?(Float)
              if raw == raw.floor
                @min_items = raw.to_i
              else
                raise InvalidSchema.new("Value for keyword 'minItems' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword 'minItems' must be a number")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_a.size >= @min_items
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
          @max_contains : Int32

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            @max_contains = 0
            if val = value.raw.as?(Int)
              @max_contains = val.to_i
            elsif val = value.raw.as?(Float)
              @max_contains = val.to_i
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number of array items at #{formatted_instance_location} matching `contains` schema is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            raw = value.raw
            if raw.is_a?(Int)
              @max_contains = raw.to_i
            elsif raw.is_a?(Float)
              if raw == raw.floor
                @max_contains = raw.to_i
              else
                raise InvalidSchema.new("Value for keyword 'maxContains' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword 'maxContains' must be a number")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            contains_result = context.adjacent_results.try(&.[Applicator::Contains]?)
            unless contains_result
              return result(instance, instance_location, keyword_location, true)
            end
            anno = contains_result.get_annotation
            if anno && anno.raw.is_a?(Array)
              valid = anno.as_a.size <= @max_contains
              result(instance, instance_location, keyword_location, valid)
            else
              result(instance, instance_location, keyword_location, true)
            end
          end
        end

        # MinContains keyword
        class MinContains < Keyword
          @min_contains : Int32

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            @min_contains = 0
            if val = value.raw.as?(Int)
              @min_contains = val.to_i
            elsif val = value.raw.as?(Float)
              @min_contains = val.to_i
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "number of array items at #{formatted_instance_location} matching `contains` schema is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            raw = value.raw
            if raw.is_a?(Int)
              @min_contains = raw.to_i
            elsif raw.is_a?(Float)
              if raw == raw.floor
                @min_contains = raw.to_i
              else
                raise InvalidSchema.new("Value for keyword 'minContains' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword 'minContains' must be a number")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end
            contains_result = context.adjacent_results.try(&.[Applicator::Contains]?)
            unless contains_result
              return result(instance, instance_location, keyword_location, true)
            end
            anno = contains_result.get_annotation
            if anno && anno.raw.is_a?(Array)
              valid = anno.as_a.size >= @min_contains
              result(instance, instance_location, keyword_location, valid)
            else
              result(instance, instance_location, keyword_location, true)
            end
          end
        end

        # MaxProperties keyword
        class MaxProperties < Keyword
          @max_properties : Int32

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            @max_properties = 0
            if val = value.raw.as?(Int)
              @max_properties = val.to_i
            elsif val = value.raw.as?(Float)
              @max_properties = val.to_i
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object size at #{formatted_instance_location} is greater than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            raw = value.raw
            if raw.is_a?(Int)
              @max_properties = raw.to_i
            elsif raw.is_a?(Float)
              if raw == raw.floor
                @max_properties = raw.to_i
              else
                raise InvalidSchema.new("Value for keyword 'maxProperties' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword 'maxProperties' must be a number")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_h.size <= @max_properties
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # MinProperties keyword
        class MinProperties < Keyword
          @min_properties : Int32

          def initialize(@value : JSON::Any, @parent : Schema | Keyword, @keyword : String, schema : Schema? = nil)
            super
            @min_properties = 0
            if val = value.raw.as?(Int)
              @min_properties = val.to_i
            elsif val = value.raw.as?(Float)
              @min_properties = val.to_i
            end
          end

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object size at #{formatted_instance_location} is less than: #{value}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            raw = value.raw
            if raw.is_a?(Int)
              @min_properties = raw.to_i
            elsif raw.is_a?(Float)
              if raw == raw.floor
                @min_properties = raw.to_i
              else
                raise InvalidSchema.new("Value for keyword 'minProperties' must be an integer")
              end
            else
              raise InvalidSchema.new("Value for keyword 'minProperties' must be a number")
            end
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end
            valid = instance.as_h.size >= @min_properties
            result(instance, instance_location, keyword_location, valid)
          end
        end

        # Required keyword
        class Required < Keyword
          @required_keys : Array(String) = [] of String

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            missing = details.try(&.["missing_keys"]?.try(&.as_a.map(&.as_s).join(", "))) || ""
            "object at #{formatted_instance_location} is missing required properties: #{missing}"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Array(String) | Hash(String, Array(String)) | Regex | Nil
            @required_keys = value.as_a.map(&.as_s)
            @required_keys
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

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
                @required_keys = @required_keys - inapplicable
              end
            end

            missing_keys = @required_keys - instance.as_h.keys
            details_hash = {"missing_keys" => JSON::Any.new(missing_keys.map { |k| JSON::Any.new(k) })}
            result(instance, instance_location, keyword_location, missing_keys.empty?, details: details_hash)
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

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            existing_keys = instance.as_h.keys
            nested = [] of Result

            @dependent_required.each do |key, required|
              next unless instance.as_h.has_key?(key)

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
