module JsonSchemer
  module Draft202012
    module Vocab
      module Applicator
        # AllOf keyword
        class AllOf < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match all `allOf` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            value.as_a.map_with_index do |subschema_value, index|
              subschema(subschema_value, index.to_s)
            end
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            schemas = parsed.as(Array(Schema))
            nested = schemas.map_with_index do |s, index|
              s.validate_instance(instance, instance_location, join_location(keyword_location, index.to_s), context)
            end
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested)
          end
        end

        # AnyOf keyword
        class AnyOf < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match any `anyOf` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            value.as_a.map_with_index do |subschema_value, index|
              subschema(subschema_value, index.to_s)
            end
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            schemas = parsed.as(Array(Schema))
            nested = schemas.map_with_index do |s, index|
              s.validate_instance(instance, instance_location, join_location(keyword_location, index.to_s), context)
            end
            result(instance, instance_location, keyword_location, nested.any?(&.valid), nested)
          end
        end

        # OneOf keyword
        class OneOf < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match exactly one `oneOf` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            value.as_a.map_with_index do |subschema_value, index|
              subschema(subschema_value, index.to_s)
            end
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            schemas = parsed.as(Array(Schema))
            nested = schemas.map_with_index do |s, index|
              s.validate_instance(instance, instance_location, join_location(keyword_location, index.to_s), context)
            end
            valid_count = nested.count(&.valid)
            result(instance, instance_location, keyword_location, valid_count == 1, nested, ignore_nested: valid_count > 1)
          end
        end

        # Not keyword
        class Not < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} matches `not` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            subschema_result = parsed.as(Schema).validate_instance(instance, instance_location, keyword_location, context)
            result(instance, instance_location, keyword_location, !subschema_result.valid, subschema_result.nested)
          end
        end

        # If keyword
        class If < Keyword
          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            subschema_result = parsed.as(Schema).validate_instance(instance, instance_location, keyword_location, context)
            result(instance, instance_location, keyword_location, true, subschema_result.nested, result_annotation: JSON::Any.new(subschema_result.valid))
          end
        end

        # Then keyword
        class Then < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match conditional `then` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            if_result = context.adjacent_results[If]?
            return nil unless if_result
            return nil unless if_result.get_annotation.try(&.as_bool?)

            subschema_result = parsed.as(Schema).validate_instance(instance, instance_location, keyword_location, context)
            result(instance, instance_location, keyword_location, subschema_result.valid, subschema_result.nested)
          end
        end

        # Else keyword
        class Else < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match conditional `else` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            if_result = context.adjacent_results[If]?
            return nil unless if_result
            return nil if if_result.get_annotation.try(&.as_bool?)

            subschema_result = parsed.as(Schema).validate_instance(instance, instance_location, keyword_location, context)
            result(instance, instance_location, keyword_location, subschema_result.valid, subschema_result.nested)
          end
        end

        # DependentSchemas keyword
        class DependentSchemas < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match applicable `dependentSchemas` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            result = {} of String => Schema
            value.as_h.each do |key, subschema_value|
              result[key] = subschema(subschema_value, key)
            end
            result
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            schemas = parsed.as(Hash(String, Schema))
            nested = [] of Result

            schemas.each do |key, s|
              next unless instance.as_h.has_key?(key)
              nested << s.validate_instance(instance, instance_location, join_location(keyword_location, key), context)
            end

            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested)
          end
        end

        # PrefixItems keyword
        class PrefixItems < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array items at #{formatted_instance_location} do not match corresponding `prefixItems` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            value.as_a.map_with_index do |subschema_value, index|
              subschema(subschema_value, index.to_s)
            end
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end

            schemas = parsed.as(Array(Schema))
            arr = instance.as_a
            nested = arr.first(schemas.size).map_with_index do |item, index|
              schemas[index].validate_instance(item, join_location(instance_location, index.to_s), join_location(keyword_location, index.to_s), context)
            end

            annotation_value = nested.size - 1
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested, result_annotation: JSON::Any.new(annotation_value.to_i64))
          end
        end

        # Items keyword
        class Items < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array items at #{formatted_instance_location} do not match `items` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end

            prefix_items_result = context.adjacent_results[PrefixItems]?
            evaluated_index = prefix_items_result.try(&.get_annotation.try(&.as_i?)) || -1
            offset = evaluated_index + 1

            items_schema = parsed.as(Schema)
            arr = instance.as_a
            nested = arr[offset..].map_with_index do |item, index|
              items_schema.validate_instance(item, join_location(instance_location, (offset + index).to_s), keyword_location, context)
            end

            anno = !nested.empty?
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested, result_annotation: JSON::Any.new(anno))
          end
        end

        # Contains keyword
        class Contains < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array at #{formatted_instance_location} does not contain enough items that match `contains` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end

            contains_schema = parsed.as(Schema)
            arr = instance.as_a
            nested = arr.map_with_index do |item, index|
              contains_schema.validate_instance(item, join_location(instance_location, index.to_s), keyword_location, context)
            end

            anno = [] of Int64
            nested.each_with_index do |nested_result, index|
              anno << index.to_i64 if nested_result.valid
            end

            min_contains = schema.parsed["minContains"]?.try do |mc|
              if mc.is_a?(Keyword)
                (mc.value.as_i? || mc.value.as_f).to_i
              else
                1
              end
            end || 1

            valid = anno.size >= min_contains
            annotation_value = JSON::Any.new(anno.map { |i| JSON::Any.new(i) })
            result(instance, instance_location, keyword_location, valid, nested, result_annotation: annotation_value, ignore_nested: true)
          end
        end

        # Properties keyword
        class Properties < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object properties at #{formatted_instance_location} do not match corresponding `properties` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            result = {} of String => Schema
            value.as_h.each do |property, subschema_value|
              result[property] = subschema(subschema_value, property)
            end
            result
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            schemas = parsed.as(Hash(String, Schema))
            evaluated_keys = [] of String
            nested = [] of Result

            schemas.each do |property, prop_schema|
              if instance.as_h.has_key?(property)
                evaluated_keys << property
                nested << prop_schema.validate_instance(
                  instance.as_h[property],
                  join_location(instance_location, property),
                  join_location(keyword_location, property),
                  context
                )
              end
            end

            anno = JSON::Any.new(evaluated_keys.map { |k| JSON::Any.new(k) })
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested, result_annotation: anno)
          end
        end

        # PatternProperties keyword
        class PatternProperties < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object properties at #{formatted_instance_location} do not match corresponding `patternProperties` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            result = {} of String => Schema
            value.as_h.each do |pattern, subschema_value|
              result[pattern] = subschema(subschema_value, pattern)
            end
            result
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            schemas = parsed.as(Hash(String, Schema))
            evaluated = Set(String).new
            nested = [] of Result

            schemas.each do |pattern, pattern_schema|
              regexp = root.resolve_regexp(pattern)
              instance.as_h.each do |key, val|
                if regexp.matches?(key)
                  evaluated << key
                  nested << pattern_schema.validate_instance(val, join_location(instance_location, key), join_location(keyword_location, pattern), context)
                end
              end
            end

            anno = JSON::Any.new(evaluated.to_a.map { |k| JSON::Any.new(k) })
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested, result_annotation: anno)
          end
        end

        # AdditionalProperties keyword
        class AdditionalProperties < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object properties at #{formatted_instance_location} do not match `additionalProperties` schema"
          end

          def false_schema_error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object property at #{formatted_instance_location} is a disallowed additional property"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            evaluated_keys = Set(String).new

            properties_result = context.adjacent_results[Properties]?
            if properties_result && properties_result.get_annotation
              properties_result.get_annotation.not_nil!.as_a.each { |k| evaluated_keys << k.as_s }
            end

            pattern_properties_result = context.adjacent_results[PatternProperties]?
            if pattern_properties_result && pattern_properties_result.get_annotation
              pattern_properties_result.get_annotation.not_nil!.as_a.each { |k| evaluated_keys << k.as_s }
            end

            additional_schema = parsed.as(Schema)
            evaluated = {} of String => JSON::Any
            nested = [] of Result

            instance.as_h.each do |key, val|
              unless evaluated_keys.includes?(key)
                evaluated[key] = val
                nested << additional_schema.validate_instance(val, join_location(instance_location, key), keyword_location, context)
              end
            end

            anno = JSON::Any.new(evaluated.keys.map { |k| JSON::Any.new(k) })
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested, result_annotation: anno)
          end
        end

        # PropertyNames keyword
        class PropertyNames < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object property names at #{formatted_instance_location} do not match `propertyNames` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            names_schema = parsed.as(Schema)
            nested = instance.as_h.keys.map do |key|
              names_schema.validate_instance(JSON::Any.new(key), instance_location, keyword_location, context)
            end

            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested)
          end
        end

        # Dependencies keyword (legacy)
        class Dependencies < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object at #{formatted_instance_location} either does not match applicable `dependencies` schemas or is missing required `dependencies` properties"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            result = {} of String => Schema | Array(String)
            value.as_h.each do |key, dep_value|
              if dep_value.raw.is_a?(Array)
                result[key] = dep_value.as_a.map(&.as_s)
              else
                result[key] = subschema(dep_value, key)
              end
            end
            result
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            deps = parsed.as(Hash(String, Schema | Array(String)))
            existing_keys = instance.as_h.keys
            nested = [] of Result

            deps.each do |key, dep_value|
              next unless instance.as_h.has_key?(key)

              case dep_value
              when Array(String)
                missing_keys = dep_value - existing_keys
                details_hash = {"missing_keys" => JSON::Any.new(missing_keys.map { |k| JSON::Any.new(k) })}
                nested << result(instance, instance_location, join_location(keyword_location, key), missing_keys.empty?, details: details_hash)
              when Schema
                nested << dep_value.validate_instance(instance, instance_location, join_location(keyword_location, key), context)
              end
            end

            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested)
          end
        end
      end
    end
  end
end
