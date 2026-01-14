module JsonSchemer
  module Draft202012
    module Vocab
      # Core vocabulary keywords
      CORE = {
        "$schema"        => Core::SchemaKeyword,
        "$vocabulary"    => Core::Vocabulary,
        "$id"            => Core::Id,
        "$anchor"        => Core::Anchor,
        "$ref"           => Core::Ref,
        "$dynamicAnchor" => Core::DynamicAnchor,
        "$dynamicRef"    => Core::DynamicRef,
        "$defs"          => Core::Defs,
        "definitions"    => Core::Defs,
        "$comment"       => Core::Comment,
        "x-error"        => Core::XError,
      } of String => Keyword.class

      # Applicator vocabulary keywords
      APPLICATOR = {
        "allOf"                => Applicator::AllOf,
        "anyOf"                => Applicator::AnyOf,
        "oneOf"                => Applicator::OneOf,
        "not"                  => Applicator::Not,
        "if"                   => Applicator::If,
        "then"                 => Applicator::Then,
        "else"                 => Applicator::Else,
        "dependentSchemas"     => Applicator::DependentSchemas,
        "prefixItems"          => Applicator::PrefixItems,
        "items"                => Applicator::Items,
        "contains"             => Applicator::Contains,
        "properties"           => Applicator::Properties,
        "patternProperties"    => Applicator::PatternProperties,
        "additionalProperties" => Applicator::AdditionalProperties,
        "propertyNames"        => Applicator::PropertyNames,
        "dependencies"         => Applicator::Dependencies,
      } of String => Keyword.class

      # Unevaluated vocabulary keywords
      UNEVALUATED = {
        "unevaluatedItems"      => Unevaluated::UnevaluatedItems,
        "unevaluatedProperties" => Unevaluated::UnevaluatedProperties,
      } of String => Keyword.class

      # Validation vocabulary keywords
      VALIDATION = {
        "type"              => Validation::Type,
        "enum"              => Validation::Enum,
        "const"             => Validation::Const,
        "multipleOf"        => Validation::MultipleOf,
        "maximum"           => Validation::Maximum,
        "exclusiveMaximum"  => Validation::ExclusiveMaximum,
        "minimum"           => Validation::Minimum,
        "exclusiveMinimum"  => Validation::ExclusiveMinimum,
        "maxLength"         => Validation::MaxLength,
        "minLength"         => Validation::MinLength,
        "pattern"           => Validation::Pattern,
        "maxItems"          => Validation::MaxItems,
        "minItems"          => Validation::MinItems,
        "uniqueItems"       => Validation::UniqueItems,
        "maxContains"       => Validation::MaxContains,
        "minContains"       => Validation::MinContains,
        "maxProperties"     => Validation::MaxProperties,
        "minProperties"     => Validation::MinProperties,
        "required"          => Validation::Required,
        "dependentRequired" => Validation::DependentRequired,
      } of String => Keyword.class

      # Format annotation vocabulary
      FORMAT_ANNOTATION = {
        "format" => FormatAnnotation::Format,
      } of String => Keyword.class

      # Format assertion vocabulary
      FORMAT_ASSERTION = {
        "format" => FormatAssertion::Format,
      } of String => Keyword.class

      # Content vocabulary
      CONTENT = {
        "contentEncoding"  => ContentVocab::ContentEncoding,
        "contentMediaType" => ContentVocab::ContentMediaType,
        "contentSchema"    => ContentVocab::ContentSchema,
      } of String => Keyword.class

      # Meta-data vocabulary
      META_DATA = {
        "readOnly"  => MetaData::ReadOnly,
        "writeOnly" => MetaData::WriteOnly,
        "default"   => MetaData::Default,
      } of String => Keyword.class

      # All keywords combined for default vocabulary
      ALL = {} of String => Keyword.class

      def self.build_all
        ALL.merge!(CORE)
        ALL.merge!(APPLICATOR)
        ALL.merge!(UNEVALUATED)
        ALL.merge!(VALIDATION)
        ALL.merge!(FORMAT_ANNOTATION)
        ALL.merge!(CONTENT)
        ALL.merge!(META_DATA)
      end
    end
  end
end

# Build the combined vocabulary
JsonSchemer::Draft202012::Vocab.build_all
