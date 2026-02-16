module JsonSchemer
  module Draft202012
    module Vocab
      module MetaData
        # ReadOnly keyword
        class ReadOnly < Keyword
          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            result(instance, instance_location, location, true, result_annotation: value)
          end
        end

        # WriteOnly keyword
        class WriteOnly < Keyword
          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            result(instance, instance_location, location, true, result_annotation: value)
          end
        end

        # Default keyword
        class Default < Keyword
          def validate(instance : JSON::Any, instance_location : Location::Node, context : Schema::Context) : Result?
            result(instance, instance_location, location, true, result_annotation: value.clone)
          end
        end
      end
    end
  end
end
