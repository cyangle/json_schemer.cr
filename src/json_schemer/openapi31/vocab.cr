module JsonSchemer
  module OpenAPI31
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
