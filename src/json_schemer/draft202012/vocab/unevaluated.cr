module JsonSchemer
  module Draft202012
    module Vocab
      module Unevaluated
        # UnevaluatedItems keyword
        class UnevaluatedItems < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array items at #{formatted_instance_location} do not match `unevaluatedItems` schema"
          end

          def false_schema_error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "array item at #{formatted_instance_location} is a disallowed unevaluated item"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Array)
              return result(instance, instance_location, keyword_location, true)
            end

            unevaluated_items = Set(Int32).new
            instance.as_a.size.times { |i| unevaluated_items << i }

            context.adjacent_results.each_value do |adjacent_result|
              collect_unevaluated_items(adjacent_result, unevaluated_items)
            end

            items_schema = parsed.as(Schema)
            nested = unevaluated_items.map do |index|
              items_schema.validate_instance(
                instance.as_a[index],
                join_location(instance_location, index.to_s),
                keyword_location,
                context
              )
            end

            anno = !nested.empty?
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested, result_annotation: JSON::Any.new(anno))
          end

          private def collect_unevaluated_items(res : Result, unevaluated_items : Set(Int32))
            case res.source
            when Applicator::PrefixItems
              if ann = res.get_annotation
                if ann.as_i?
                  (0..ann.as_i).each { |i| unevaluated_items.delete(i) }
                end
              end
            when Applicator::Items, UnevaluatedItems
              if res.get_annotation.try(&.as_bool?)
                unevaluated_items.clear
              end
            when Applicator::Contains
              if ann = res.get_annotation
                if ann.raw.is_a?(Array)
                  ann.as_a.each { |i| unevaluated_items.delete(i.as_i) }
                end
              end
            end

            res.nested.try(&.each do |subresult|
              if subresult.valid && subresult.instance_location == res.instance_location
                collect_unevaluated_items(subresult, unevaluated_items)
              end
            end)
          end
        end

        # UnevaluatedProperties keyword
        class UnevaluatedProperties < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object properties at #{formatted_instance_location} do not match `unevaluatedProperties` schema"
          end

          def false_schema_error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "object property at #{formatted_instance_location} is a disallowed unevaluated property"
          end

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, true)
            end

            evaluated_keys = Set(String).new

            context.adjacent_results.each_value do |adjacent_result|
              collect_evaluated_keys(adjacent_result, evaluated_keys)
            end

            props_schema = parsed.as(Schema)
            evaluated = {} of String => JSON::Any
            nested = [] of Result

            instance.as_h.each do |key, val|
              unless evaluated_keys.includes?(key)
                evaluated[key] = val
                nested << props_schema.validate_instance(val, join_location(instance_location, key), keyword_location, context)
              end
            end

            anno = JSON::Any.new(evaluated.keys.map { |k| JSON::Any.new(k) })
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested, result_annotation: anno)
          end

          private def collect_evaluated_keys(res : Result, evaluated_keys : Set(String))
            case res.source
            when Applicator::Properties, Applicator::PatternProperties, Applicator::AdditionalProperties, UnevaluatedProperties
              if ann = res.get_annotation
                if ann.raw.is_a?(Array)
                  ann.as_a.each { |k| evaluated_keys << k.as_s }
                end
              end
            end

            res.nested.try(&.each do |subresult|
              if subresult.valid && subresult.instance_location == res.instance_location
                collect_evaluated_keys(subresult, evaluated_keys)
              end
            end)
          end
        end
      end
    end
  end
end
