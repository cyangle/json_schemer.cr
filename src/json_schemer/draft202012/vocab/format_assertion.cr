module JsonSchemer
  module Draft202012
    module Vocab
      module FormatAssertion
        # Format keyword (assertion)
        class Format < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match format: #{value.as_s}"
          end

          protected def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            {% unless flag?(:with_simpleidn) %}
              if (str = value.as_s?) && (str == "idn-hostname")
                Log.warn { "Schema contains '#{str}' format but `with_simpleidn` flag is not set. Validation will be disabled (always invalid)." }
              end
            {% end %}
            value
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            format_name = value.as_s

            # Try to find the format validator
            validator = root.fetch_format(format_name)

            if validator
              {% if flag?(:with_simpleidn) %}
                begin
                  valid = validator.call(instance, format_name)
                  result(instance, instance_location, keyword_location, valid, type: "format", result_annotation: value)
                rescue ex : SimpleIDN::ConversionError
                  result(instance, instance_location, keyword_location, false, type: "format", details: {"error" => JSON::Any.new(ex.message)})
                end
              {% else %}
                valid = validator.call(instance, format_name)
                result(instance, instance_location, keyword_location, valid, type: "format", result_annotation: value)
              {% end %}
            else
              # Unknown format - pass by default
              result(instance, instance_location, keyword_location, true, result_annotation: value)
            end
          end
        end
      end
    end
  end
end
