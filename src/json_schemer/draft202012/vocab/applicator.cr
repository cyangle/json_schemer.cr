module JsonSchemer
  module Draft202012
    module Vocab
      module Applicator
        # AllOf keyword
        class AllOf < Keyword
          @schemas : Array(Schema) = [] of Schema

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match all `allOf` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @schemas = parse_subschema_array
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            if context.short_circuit
              nested = [] of Result
              valid = true
              @schemas.each do |subschema|
                res = subschema.validate_instance(instance, instance_location, context)
                nested << res
                unless res.valid
                  valid = false
                  break
                end
              end
              result(instance, instance_location, location, valid, nested)
            else
              nested = @schemas.map_with_index do |subschema, _|
                subschema.validate_instance(instance, instance_location, context)
              end
              result(instance, instance_location, location, nested.all?(&.valid), nested)
            end
          end
        end

        # AnyOf keyword
        class AnyOf < Keyword
          @schemas : Array(Schema) = [] of Schema

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match any `anyOf` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @schemas = parse_subschema_array
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            nested = @schemas.map_with_index do |subschema, _|
              subschema.validate_instance(instance, instance_location, context)
            end
            result(instance, instance_location, location, nested.any?(&.valid), nested)
          end
        end

        # OneOf keyword
        class OneOf < Keyword
          @schemas : Array(Schema) = [] of Schema

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match exactly one `oneOf` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @schemas = parse_subschema_array
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            if context.short_circuit
              valid_count = 0
              nested = [] of Result
              @schemas.each do |subschema|
                res = subschema.validate_instance(instance, instance_location, context)
                nested << res
                if res.valid
                  valid_count += 1
                  if valid_count > 1
                    break # Optimization: if we already have > 1 valid, we know it will fail OneOf
                  end
                end
              end
              # NOTE: Short-circuiting here is partial. If we break early, we effectively fail.
              # But we must ensure result reflects that.
              # If we broke because valid_count > 1, then valid_count == 2 (at least).
              result(instance, instance_location, location, valid_count == 1, nested, ignore_nested: valid_count > 1)
            else
              nested = @schemas.map_with_index do |subschema, _|
                subschema.validate_instance(instance, instance_location, context)
              end
              valid_count = nested.count(&.valid)
              result(instance, instance_location, location, valid_count == 1, nested, ignore_nested: valid_count > 1)
            end
          end
        end

        # Not keyword
        class Not < Keyword
          @subschema : Schema?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} matches `not` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            subschema_obj = @subschema
            return nil unless subschema_obj
            subschema_result = subschema_obj.validate_instance(instance, instance_location, context)
            result(instance, instance_location, location, !subschema_result.valid, subschema_result.nested)
          end
        end

        # If keyword
        class If < Keyword
          @subschema : Schema?

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            subschema_obj = @subschema
            return nil unless subschema_obj
            subschema_result = subschema_obj.validate_instance(instance, instance_location, context)
            result(instance, instance_location, location, true, subschema_result.nested, result_annotation: JSON::Any.new(subschema_result.valid))
          end
        end

        # Then keyword
        class Then < Keyword
          @subschema : Schema?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match conditional `then` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            if_result = context.adjacent_results.try(&.[If]?)
            return nil unless if_result
            return nil unless if_result.annotation.try(&.as_bool?)

            subschema_obj = @subschema
            return nil unless subschema_obj
            subschema_result = subschema_obj.validate_instance(instance, instance_location, context)
            result(instance, instance_location, location, subschema_result.valid, subschema_result.nested)
          end
        end

        # Else keyword
        class Else < Keyword
          @subschema : Schema?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match conditional `else` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            if_result = context.adjacent_results.try(&.[If]?)
            return nil unless if_result
            return nil if if_result.annotation.try(&.as_bool?)

            subschema_obj = @subschema
            return nil unless subschema_obj
            subschema_result = subschema_obj.validate_instance(instance, instance_location, context)
            result(instance, instance_location, location, subschema_result.valid, subschema_result.nested)
          end
        end

        # DependentSchemas keyword
        class DependentSchemas < Keyword
          @schemas : Hash(String, Schema) = {} of String => Schema

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match applicable `dependentSchemas` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @schemas = parse_subschema_hash
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end

            nested = [] of Result

            @schemas.each do |key, subschema|
              next unless instance.as_h.has_key?(key)
              nested << subschema.validate_instance(instance, instance_location, context)
            end

            result(instance, instance_location, location, nested.all?(&.valid), nested)
          end
        end

        # PrefixItems keyword
        class PrefixItems < Keyword
          @schemas : Array(Schema) = [] of Schema

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array items at #{formatted_instance_location} do not match corresponding `prefixItems` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @schemas = parse_subschema_array
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, location, true)
            end

            arr = instance.as_a
            nested = arr.first(@schemas.size).map_with_index do |item, index|
              @schemas[index].validate_instance(item, join_location(instance_location, index.to_s), context)
            end

            annotation_value = if nested.size == arr.size
                                 true
                               else
                                 (nested.size - 1).to_i64
                               end
            result(instance, instance_location, location, nested.all?(&.valid), nested, result_annotation: JSON::Any.new(annotation_value))
          end
        end

        # Items keyword
        class Items < Keyword
          @subschema : Schema?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array items at #{formatted_instance_location} do not match `items` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, location, true)
            end

            prefix_items_result = context.adjacent_results.try(&.[PrefixItems]?)
            offset = if prefix_items_result && prefix_items_result.annotation.try(&.as_bool?)
                       instance.as_a.size
                     else
                       evaluated_index = prefix_items_result.try(&.annotation.try(&.as_i?)) || -1
                       evaluated_index + 1
                     end

            items_schema = @subschema
            return result(instance, instance_location, location, true) unless items_schema
            arr = instance.as_a
            nested = arr[offset..].map_with_index do |item, index|
              items_schema.validate_instance(item, join_location(instance_location, (offset + index).to_s), context)
            end

            anno = !nested.empty?
            result(instance, instance_location, location, nested.all?(&.valid), nested, result_annotation: JSON::Any.new(anno))
          end
        end

        # Contains keyword
        class Contains < Keyword
          @subschema : Schema?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array at #{formatted_instance_location} does not contain enough items that match `contains` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, location, true)
            end

            contains_schema = @subschema
            return result(instance, instance_location, location, true) unless contains_schema
            arr = instance.as_a
            nested = arr.map_with_index do |item, index|
              contains_schema.validate_instance(item, join_location(instance_location, index.to_s), context)
            end

            anno = nested.each_with_index.compact_map { |result, idx| idx.to_i64 if result.valid }.to_a

            min_contains = schema.parsed["minContains"]?.try do |min_kw|
              if min_kw.is_a?(Keyword)
                (min_kw.value.as_i? || min_kw.value.as_f).to_i
              else
                1
              end
            end || 1

            valid = anno.size >= min_contains
            annotation_value = JSON::Any.new(anno.map { |i| JSON::Any.new(i) })
            result(instance, instance_location, location, valid, nested, result_annotation: annotation_value, ignore_nested: true)
          end
        end

        # Properties keyword
        class Properties < Keyword
          getter schemas : Hash(String, Schema) = {} of String => Schema

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object properties at #{formatted_instance_location} do not match corresponding `properties` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @schemas = parse_subschema_hash
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end

            evaluated_keys = [] of String
            nested = [] of Result

            before_hooks = root.configuration.before_property_validation
            after_hooks = root.configuration.after_property_validation

            @schemas.each do |property, prop_schema|
              if instance.as_h.has_key?(property)
                evaluated_keys << property
                property_value = instance.as_h[property]

                # Call before_property_validation hooks
                before_hooks.each do |hook|
                  hook.call(property_value, property, prop_schema.value, instance)
                end

                prop_result = prop_schema.validate_instance(
                  property_value,
                  join_location(instance_location, property),
                  context
                )
                nested << prop_result

                # Call after_property_validation hooks
                after_hooks.each do |hook|
                  hook.call(property_value, property, prop_schema.value, instance)
                end
              end
            end

            anno = JSON::Any.new(evaluated_keys.map { |k| JSON::Any.new(k) })
            result(instance, instance_location, location, nested.all?(&.valid), nested, result_annotation: anno)
          end
        end

        # PatternProperties keyword
        class PatternProperties < Keyword
          @schemas : Hash(String, Schema) = {} of String => Schema

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object properties at #{formatted_instance_location} do not match corresponding `patternProperties` schemas"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @schemas = parse_subschema_hash
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end

            evaluated = Set(String).new
            nested = [] of Result

            @schemas.each do |pattern, pattern_schema|
              regexp = root.resolve_regexp(pattern)
              instance.as_h.each do |key, val|
                if regexp.matches?(key)
                  evaluated << key
                  nested << pattern_schema.validate_instance(val, join_location(instance_location, key), context)
                end
              end
            end

            anno = JSON::Any.new(evaluated.to_a.map { |k| JSON::Any.new(k) })
            result(instance, instance_location, location, nested.all?(&.valid), nested, result_annotation: anno)
          end
        end

        # AdditionalProperties keyword
        class AdditionalProperties < Keyword
          @subschema : Schema?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object properties at #{formatted_instance_location} do not match `additionalProperties` schema"
          end

          def false_schema_error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object property at #{formatted_instance_location} is a disallowed additional property"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end

            evaluated_keys = Set(String).new

            properties_result = context.adjacent_results.try(&.[Properties]?)
            if properties_result
              if ann = properties_result.annotation
                evaluated_keys.concat(ann.as_a.map(&.as_s))
              end
            end

            pattern_properties_result = context.adjacent_results.try(&.[PatternProperties]?)
            if pattern_properties_result
              if ann = pattern_properties_result.annotation
                evaluated_keys.concat(ann.as_a.map(&.as_s))
              end
            end

            additional_schema = @subschema
            return result(instance, instance_location, location, true) unless additional_schema
            evaluated = {} of String => JSON::Any
            nested = [] of Result

            instance.as_h.each do |key, val|
              unless evaluated_keys.includes?(key)
                evaluated[key] = val
                nested << additional_schema.validate_instance(val, join_location(instance_location, key), context)
              end
            end

            anno = JSON::Any.new(evaluated.keys.map { |k| JSON::Any.new(k) })
            result(instance, instance_location, location, nested.all?(&.valid), nested, result_annotation: anno)
          end
        end

        # PropertyNames keyword
        class PropertyNames < Keyword
          @subschema : Schema?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object property names at #{formatted_instance_location} do not match `propertyNames` schema"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end

            names_schema = @subschema
            return result(instance, instance_location, location, true) unless names_schema
            nested = instance.as_h.keys.map do |key|
              names_schema.validate_instance(JSON::Any.new(key), instance_location, context)
            end

            result(instance, instance_location, location, nested.all?(&.valid), nested)
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

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, true)
            end

            deps = parsed.as(Hash(String, Schema | Array(String)))
            existing_keys = instance.as_h
            nested = [] of Result

            deps.each do |key, dep_value|
              next unless existing_keys.has_key?(key)

              case dep_value
              when Array(String)
                valid = dep_value.all? { |k| existing_keys.has_key?(k) }
                unless valid
                  missing_keys = dep_value.reject { |k| existing_keys.has_key?(k) }
                  details_hash = {"missing_keys" => JSON::Any.new(missing_keys.map { |k| JSON::Any.new(k) })}
                  nested << result(instance, instance_location, location, false, details: details_hash)
                end
              when Schema
                nested << dep_value.validate_instance(instance, instance_location, context)
              end
            end

            result(instance, instance_location, location, nested.all?(&.valid), nested)
          end
        end
      end
    end
  end
end
