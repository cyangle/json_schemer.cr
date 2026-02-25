module JsonSchemer
  module OpenAPI3
    module Vocab
      module Base
        # AllOf with discriminator support
        class AllOf < Draft202012::Vocab::Applicator::AllOf
          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            schemas = parsed.as(Array(Schema))
            nested = [] of Result

            schemas.each do |subschema|
              ref_kw = subschema.parsed["$ref"]?
              if ref_kw.is_a?(Draft202012::Vocab::Core::Ref)
                ref_schema = ref_kw.ref_schema
                next if context.discriminator_skip.includes?(ref_schema.absolute_keyword_location)

                disc_kw = ref_schema.parsed["discriminator"]?
                if disc_kw.is_a?(Discriminator)
                  context.discriminator_skip.add(schema.absolute_keyword_location)
                end
              end

              nested << subschema.validate_instance(instance, instance_location, context)
            end

            result(instance, instance_location, location, nested.all?(&.valid), nested)
          end
        end

        # AnyOf with discriminator support
        class AnyOf < Draft202012::Vocab::Applicator::AnyOf
          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            return nil if schema.parsed.has_key?("discriminator")
            super
          end
        end

        # OneOf with discriminator support
        class OneOf < Draft202012::Vocab::Applicator::OneOf
          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            return nil if schema.parsed.has_key?("discriminator")
            super
          end
        end

        # Discriminator keyword
        class Discriminator < Keyword
          FIXED_FIELD_REGEX = /\A[a-zA-Z0-9\.\-_]+\z/

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match `discriminator` schema"
          end

          def mapping : Hash(String, JSON::Any)
            value.as_h["mapping"]?.try(&.as_h) || {} of String => JSON::Any
          end

          # OpenAPI 3.2: defaultMapping provides a fallback schema when discriminator value doesn't match
          def default_mapping : String?
            value.as_h["defaultMapping"]?.try(&.as_s)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, location, false)
            end

            # OpenAPI 3.2: propertyName is optional
            # If missing, skip discriminator validation and let underlying schema handle it
            property_name_val = value.as_h["propertyName"]?
            return nil unless property_name_val

            property_name = property_name_val.as_s
            unless instance.as_h.has_key?(property_name)
              return result(instance, instance_location, location, false)
            end

            property_value = instance.as_h[property_name].as_s?
            return result(instance, instance_location, location, false) unless property_value

            subschema = resolve_subschema(property_value)

            # OpenAPI 3.2: If no matching subschema and defaultMapping is set, use it as fallback
            unless subschema
              if default_map = default_mapping
                subschema = resolve_schema_ref(default_map)
                unless subschema
                  Log.warn { "defaultMapping '#{default_map}' could not be resolved" }
                end
              end
            end

            return result(instance, instance_location, location, false) unless subschema

            return nil if context.discriminator_skip.includes?(subschema.absolute_keyword_location)

            all_of_kw = subschema.parsed["allOf"]?
            if all_of_kw.is_a?(AllOf)
              context.discriminator_skip.add(schema.absolute_keyword_location)
            end

            subschema_result = subschema.validate_instance(instance, instance_location, context)

            result(instance, instance_location, location, subschema_result.valid, subschema_result.nested)
          end

          private def resolve_subschema(property_value : String) : Schema?
            # Check if anyOf or oneOf is present
            any_of = schema.parsed["anyOf"]?
            one_of = schema.parsed["oneOf"]?

            if any_of.is_a?(Keyword) || one_of.is_a?(Keyword)
              subschemas = [] of Schema
              if any_of.is_a?(Keyword) && any_of.parsed.is_a?(Array(Schema))
                subschemas += any_of.parsed.as(Array(Schema))
              end
              if one_of.is_a?(Keyword) && one_of.parsed.is_a?(Array(Schema))
                subschemas += one_of.parsed.as(Array(Schema))
              end

              # Build mapping
              by_ref = {} of String => Schema
              by_name = {} of String => Schema

              subschemas.each do |subschema|
                ref_kw = subschema.parsed["$ref"]?
                if ref_kw.is_a?(Draft202012::Vocab::Core::Ref)
                  ref_str = ref_kw.value.as_s
                  by_ref[ref_str] = subschema

                  if ref_str.starts_with?("#/components/schemas/")
                    schema_name = ref_str.sub("#/components/schemas/", "")
                    if RegexpHelper.matches?(FIXED_FIELD_REGEX, schema_name)
                      by_name[schema_name] = subschema
                    end
                  end
                end
              end

              # Check explicit mapping
              mapping_val = mapping[property_value]?
              if mapping_val
                mapping_str = mapping_val.as_s
                return by_name[mapping_str]? || by_ref[mapping_str]?
              end

              # Check implicit mapping
              return by_name[property_value]? if by_name.has_key?(property_value)
            end

            # Fallback to ref resolution
            mapping_val = mapping[property_value]?
            schema_ref = if mapping_val
                           mapping_val.as_s
                         else
                           property_value
                         end

            resolve_schema_ref(schema_ref)
          end

          # Resolve schema reference (with component shorthand support)
          private def resolve_schema_ref(schema_ref : String) : Schema?
            if RegexpHelper.matches?(FIXED_FIELD_REGEX, schema_ref)
              begin
                return schema.ref("#/components/schemas/#{schema_ref}")
              rescue InvalidRefPointer
              end
            end

            begin
              schema.ref(schema_ref)
            rescue InvalidRefResolution | UnknownRef
              nil
            end
          end
        end
      end
    end
  end
end
