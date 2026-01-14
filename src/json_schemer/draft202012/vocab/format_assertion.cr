module JsonSchemer
  module Draft202012
    module Vocab
      module FormatAssertion
        # Format keyword (assertion)
        class Format < Keyword
          def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
            "value at #{formatted_instance_location} does not match format: #{value.as_s}"
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            format_name = value.as_s

            # Try to find the format validator
            validator = root.fetch_format(format_name)

            if validator
              valid = validator.call(instance, format_name)
              result(instance, instance_location, keyword_location, valid, type: "format", result_annotation: value)
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
