module JsonSchemer
  module Draft202012
    module Vocab
      module FormatAnnotation
        # Format keyword (annotation only)
        class Format < Keyword
          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            result(instance, instance_location, keyword_location, true, result_annotation: value)
          end
        end
      end
    end
  end
end
