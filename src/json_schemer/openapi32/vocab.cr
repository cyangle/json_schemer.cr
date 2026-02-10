module JsonSchemer
  module OpenAPI32
    module Vocab
      BASE = {
        "allOf"         => Base::AllOf,
        "anyOf"         => Base::AnyOf,
        "oneOf"         => Base::OneOf,
        "discriminator" => Base::Discriminator,
      } of String => Keyword.class
    end
  end
end
