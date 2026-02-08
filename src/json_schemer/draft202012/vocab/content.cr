module JsonSchemer
  module Draft202012
    module Vocab
      module ContentVocab
        # ContentEncoding keyword
        class ContentEncoding < Keyword
          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, location, true)
            end

            encoding_name = value.as_s
            encoder = root.fetch_content_encoding(encoding_name)

            if encoder
              success, decoded = encoder.call(instance.as_s)
              if success && decoded
                anno = JSON::Any.new(decoded)
                result(instance, instance_location, location, true, result_annotation: anno)
              else
                result(instance, instance_location, location, true)
              end
            else
              result(instance, instance_location, location, true)
            end
          end
        end

        # ContentMediaType keyword
        class ContentMediaType < Keyword
          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            unless instance.raw.is_a?(String)
              return result(instance, instance_location, location, true)
            end

            # Get decoded content from contentEncoding if present
            content = instance.as_s
            encoding_result = context.adjacent_results.try(&.[ContentEncoding]?)
            if encoding_result && encoding_result.annotation
              ann = encoding_result.annotation
              if ann && ann.as_s?
                content = ann.as_s
              end
            end

            media_type = value.as_s
            parser = root.fetch_content_media_type(media_type)

            if parser
              success, parsed_content = parser.call(content)
              if success && parsed_content
                result(instance, instance_location, location, true, result_annotation: parsed_content)
              else
                result(instance, instance_location, location, true)
              end
            else
              result(instance, instance_location, location, true)
            end
          end
        end

        # ContentSchema keyword
        class ContentSchema < Keyword
          @subschema : Schema?

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            @subschema = subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            # contentSchema only applies when contentMediaType is present
            media_type_result = context.adjacent_results.try(&.[ContentMediaType]?)
            return result(instance, instance_location, location, true) unless media_type_result

            anno = media_type_result.annotation
            return result(instance, instance_location, location, true) unless anno

            content_schema = @subschema
            return result(instance, instance_location, location, true) unless content_schema
            subschema_result = content_schema.validate_instance(anno, instance_location, context)
            result(instance, instance_location, location, true, subschema_result.nested, result_annotation: JSON::Any.new(subschema_result.valid))
          end
        end
      end
    end
  end
end
