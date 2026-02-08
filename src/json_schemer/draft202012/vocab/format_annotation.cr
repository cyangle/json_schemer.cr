module JsonSchemer
  module Draft202012
    module Vocab
      module FormatAnnotation
        # Format keyword (annotation only)
        class Format < Keyword
          protected def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            {% unless flag?(:with_simpleidn) %}
              if (str = value.as_s?) && (str == "idn-hostname")
                Log.warn { "Schema contains '#{str}' format but `with_simpleidn` flag is not set. Validation will be disabled (always invalid)." }
              end
            {% end %}
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            result(instance, instance_location, location, true, result_annotation: value)
          end
        end
      end
    end
  end
end
