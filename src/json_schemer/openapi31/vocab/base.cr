module JsonSchemer
  module OpenAPI31
    module Vocab
      module Base
        # AllOf with discriminator support
        class AllOf < Draft202012::Vocab::Applicator::AllOf
          property skip_ref_once : String?

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            schemas = parsed.as(Array(Schema))
            nested = [] of Result

            schemas.each_with_index do |s, index|
              ref_kw = s.parsed["$ref"]?
              if ref_kw.is_a?(Draft202012::Vocab::Core::Ref)
                ref_schema = ref_kw.ref_schema
                next if skip_ref_once == ref_schema.absolute_keyword_location

                disc_kw = ref_schema.parsed["discriminator"]?
                if disc_kw.is_a?(Discriminator)
                  disc_kw.skip_ref_once = schema.absolute_keyword_location
                end
              end

              nested << s.validate_instance(instance, instance_location, join_location(keyword_location, index.to_s), context)
            end

            @skip_ref_once = nil
            result(instance, instance_location, keyword_location, nested.all?(&.valid), nested)
          end
        end

        # AnyOf with discriminator support
        class AnyOf < Draft202012::Vocab::Applicator::AnyOf
          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            return nil if schema.parsed.has_key?("discriminator")
            super
          end
        end

        # OneOf with discriminator support
        class OneOf < Draft202012::Vocab::Applicator::OneOf
          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            return nil if schema.parsed.has_key?("discriminator")
            super
          end
        end

        # Discriminator keyword
        class Discriminator < Keyword
          FIXED_FIELD_REGEX = /\A[a-zA-Z0-9\.\-_]+\z/

          property skip_ref_once : String?

          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match `discriminator` schema"
          end

          def mapping : Hash(String, JSON::Any)
            value.as_h["mapping"]?.try(&.as_h) || {} of String => JSON::Any
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(Hash)
              return result(instance, instance_location, keyword_location, false)
            end

            property_name = value.as_h["propertyName"].as_s
            unless instance.as_h.has_key?(property_name)
              return result(instance, instance_location, keyword_location, false)
            end

            property_value = instance.as_h[property_name].as_s?
            return result(instance, instance_location, keyword_location, false) unless property_value

            subschema = resolve_subschema(property_value)
            return result(instance, instance_location, keyword_location, false) unless subschema

            return nil if skip_ref_once == subschema.absolute_keyword_location

            all_of_kw = subschema.parsed["allOf"]?
            if all_of_kw.is_a?(AllOf)
              all_of_kw.skip_ref_once = schema.absolute_keyword_location
            end

            subschema_result = subschema.validate_instance(instance, instance_location, keyword_location, context)
            @skip_ref_once = nil

            result(instance, instance_location, keyword_location, subschema_result.valid, subschema_result.nested)
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

              subschemas.each do |s|
                ref_kw = s.parsed["$ref"]?
                if ref_kw.is_a?(Draft202012::Vocab::Core::Ref)
                  ref_str = ref_kw.value.as_s
                  by_ref[ref_str] = s

                  if ref_str.starts_with?("#/components/schemas/")
                    schema_name = ref_str.sub("#/components/schemas/", "")
                    if FIXED_FIELD_REGEX.matches?(schema_name)
                      by_name[schema_name] = s
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
              # Also check if case-insensitive match exists (optional improvement, but fixes tests if they mismatch case)
              # The spec doesn't mandate case insensitivity but implies the value is the schema name.
              # If schema names are capitalized but value is not, we might need to handle it.
              # However, Ruby implementation handles this by `delete_prefix` which returns the exact suffix.
              # The issue in test was likely that instance value was "circle" and schema name "Circle".
              # Wait, Ruby test uses `type: 'circle'` and `Circle` schema has `type: {const: 'circle'}`.
              # But `Circle` schema definition key IS `Circle`.
              # `by_name` stores `Circle`.
              # `property_value` is `circle`.
              # `by_name["circle"]` is nil.

              # Is there a special rule about case?
              # Or does `resolve_subschema` in Ruby handle it?
              # I checked Ruby code: it doesn't seem to do case conversion.

              # Wait, `test_one_of_discriminator` (lines 305-338):
              # 'Circle': { ..., 'properties': { 'type': {'const': 'circle'} } }
              # Instance: `{"type": "circle", ...}`.
              # Discriminator `propertyName: type`.
              # No mapping.
              # Implicit mapping: `type` value is `circle`.
              # Schema key is `Circle`.
              # `circle` != `Circle`.
              # So how does Ruby pass?

              # Maybe Ruby test uses `schema('MyResponseType')`.
              # `MyResponseType` has `oneOf` with `Circle`.

              # In Ruby, `resolve_subschema` uses `by_name`.
              # `by_name` uses `delete_prefix`.
              # Maybe `Circle` schema has a different name in the test?
              # No, it's key `Circle`.

              # Ah, maybe I should check if `resolve_subschema` tries to use `property_value` as a ref directly?
              # If `by_name` fails, it falls back to `ref`.
              # `schema.ref("circle")`.
              # `circle` is not a valid ref relative to... wait.
              # If root is `.../components/schemas/MyResponseType`? No.
              # Root is document.

              # Maybe the test relies on `property_value` being case-insensitive?
              # Or maybe I misread the test data?
              # In `test_one_of_discriminator`:
              # `circle = JSON.parse(%q({"type": "circle", "radius": 5}))` in my spec.
              # Ruby: `CAT = { ..., 'petType' => 'Cat' }`.
              # Wait, I am looking at `test_one_of_discriminator` in Ruby (lines 305+).
              # It uses `CAT`, `DOG`.
              # `CAT` is defined at top: `'petType' => 'Cat'`.
              # `Cat` schema name is `Cat`.
              # So `Cat` matches `Cat`.
              # Case matches!

              # In my ported test `spec/openapi_spec.cr`, I used:
              # `Circle`: `const: circle`.
              # Instance `type: circle`.
              # Schema name `Circle`.
              # Mismatch!

              # So I introduced the bug in my test data by lowercasing the instance type but keeping schema name capitalized.
              # I should fix the test case to match case.

              return by_name[property_value]?
            end

            # Fallback to ref resolution
            mapping_val = mapping[property_value]?
            schema_ref = if mapping_val
                           mapping_val.as_s
                         else
                           property_value
                         end

            if FIXED_FIELD_REGEX.matches?(schema_ref)
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
