module JsonSchemer
  module Draft202012
    module Vocab
      module Core
        # $schema keyword
        class SchemaKeyword < Keyword
          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            value_str = value.as_s
            new_meta_schema = if value_str == schema.base_uri.to_s
                                schema
                              else
                                # Look up in meta schemas
                                if JsonSchemer::META_SCHEMA_CALLABLES_BY_BASE_URI_STR.has_key?(value_str)
                                  JsonSchemer::META_SCHEMA_CALLABLES_BY_BASE_URI_STR[value_str].call
                                else
                                  root.resolve_ref(URI.parse(value_str))
                                end
                              end
            schema.meta_schema = new_meta_schema
            value
          end
        end

        # $vocabulary keyword
        class Vocabulary < Keyword
          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            vocabularies = {} of String => Hash(String, Keyword.class)

            value.as_h.each do |vocab, required|
              if JsonSchemer::VOCABULARIES.has_key?(vocab)
                vocabularies[vocab] = JsonSchemer::VOCABULARIES[vocab]
              elsif required.as_bool
                raise UnknownVocabulary.new(vocab)
              end
            end

            # Build keywords from vocabularies
            keywords = {} of String => Keyword.class
            keyword_order = {} of String => Int32

            sorted_vocabs = vocabularies.to_a.sort_by do |vocab, _|
              JsonSchemer::VOCABULARY_ORDER[vocab]? || Int32::MAX
            end

            index = 0
            sorted_vocabs.each do |_vocab, vocab_keywords|
              vocab_keywords.each do |kw, klass|
                keywords[kw] = klass
                keyword_order[kw] = index
                index += 1
              end
            end

            schema.keywords = keywords
            schema.keyword_order = keyword_order

            value
          end
        end

        # $id keyword
        class Id < Keyword
          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            uri = URI.parse(value.as_s)
            resolved = schema.base_uri.resolve(uri)
            schema.base_uri = resolved
            root.resources[:lexical][resolved] = schema
            value
          end
        end

        # $anchor keyword
        class Anchor < Keyword
          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            uri = schema.base_uri.dup
            uri.fragment = value.as_s
            root.resources[:lexical][uri] = schema
            value
          end
        end

        # $ref keyword
        class Ref < Keyword
          @ref_uri : URI?
          @ref_schema : Schema?

          def self.exclusive? : Bool
            false
          end

          def ref_uri : URI
            @ref_uri ||= resolve_uri_reference(schema.base_uri, value.as_s)
          end

          def ref_schema : Schema
            @ref_schema ||= root.resolve_ref(ref_uri)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            ref_schema.validate_instance(instance, instance_location, keyword_location, context)
          end

          private def resolve_uri_reference(base : URI, ref_str : String) : URI
            ref = URI.parse(ref_str)
            # Handle fragment-only refs for opaque URIs (like urn:)
            # Crystal's URI.resolve doesn't work correctly for opaque URIs
            if ref.scheme.nil? && ref.path.empty? && ref.fragment
              result = base.dup
              result.fragment = ref.fragment
              result
            else
              base.resolve(ref)
            end
          end
        end

        # $dynamicAnchor keyword
        class DynamicAnchor < Keyword
          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            uri = schema.base_uri.dup
            uri.fragment = value.as_s
            root.resources[:lexical][uri] = schema
            root.resources[:dynamic][uri] = schema
            value
          end
        end

        # $dynamicRef keyword
        class DynamicRef < Keyword
          @ref_uri : URI?
          @ref_schema : Schema?
          @dynamic_anchor : String?
          @dynamic_anchor_checked : Bool = false

          def ref_uri : URI
            @ref_uri ||= resolve_uri_reference(schema.base_uri, value.as_s)
          end

          def ref_schema : Schema
            @ref_schema ||= root.resolve_ref(ref_uri)
          end

          def dynamic_anchor : String?
            return @dynamic_anchor if @dynamic_anchor_checked
            @dynamic_anchor_checked = true

            da = ref_schema.parsed["$dynamicAnchor"]?
            if da.is_a?(Keyword)
              fragment = da.value.as_s?
              if fragment && fragment == ref_uri.fragment
                @dynamic_anchor = fragment
              end
            end
            @dynamic_anchor
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            resolved_schema = ref_schema

            if anchor = dynamic_anchor
              context.dynamic_scope.each do |ancestor|
                dynamic_uri = ancestor.base_uri.dup
                dynamic_uri.fragment = anchor
                if ancestor.root.resources[:dynamic].key?(dynamic_uri)
                  resolved_schema = ancestor.root.resources[:dynamic][dynamic_uri].as(Schema)
                  break
                end
              end
            end

            resolved_schema.validate_instance(instance, instance_location, keyword_location, context)
          end

          private def resolve_uri_reference(base : URI, ref_str : String) : URI
            ref = URI.parse(ref_str)
            # Handle fragment-only refs for opaque URIs (like urn:)
            # Crystal's URI.resolve doesn't work correctly for opaque URIs
            if ref.scheme.nil? && ref.path.empty? && ref.fragment
              result = base.dup
              result.fragment = ref.fragment
              result
            else
              base.resolve(ref)
            end
          end
        end

        # $defs keyword
        class Defs < Keyword
          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            result = {} of String => Schema
            value.as_h.each do |key, subschema_value|
              result[key] = subschema(subschema_value, key)
            end
            result
          end
        end

        # $comment keyword - no validation
        class Comment < Keyword
        end

        # x-error keyword for custom error messages
        class XError < Keyword
          def message(error_key : String) : String?
            case value.raw
            when Hash
              (value.as_h[error_key]? || value.as_h[JsonSchemer::CATCHALL]?).try(&.as_s?)
            when String
              value.as_s
            else
              nil
            end
          end
        end

        # Unknown keyword handler
        class UnknownKeyword < Keyword
          @parsed_schema : Schema? = nil

          def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
            case value.raw
            when Hash
              {} of String => Schema
            when Array
              [] of Schema
            else
              value
            end
          end

          def fetch(token : String) : Schema | Keyword
            p = parsed
            case p
            when Hash(String, Schema)
              if !p.has_key?(token)
                new_kw = UnknownKeyword.new(value.as_h[token], self, token, schema)
                p[token] = new_kw.parsed_schema || subschema(value.as_h[token], token)
              end
              p[token]
            when Array(Schema)
              idx = token.to_i
              if p.size <= idx
                p << subschema(value.as_a[idx], token)
              end
              p[idx]
            else
              raise KeyError.new("Cannot fetch from: #{p.class}")
            end
          end

          def parsed_schema : Schema?
            @parsed_schema ||= subschema(value)
          end

          def validate(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Schema::Context) : Result?
            result(instance, instance_location, keyword_location, true, result_annotation: value)
          end
        end
      end
    end
  end
end
