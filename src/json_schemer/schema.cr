module JsonSchemer
  # Main Schema class for JSON Schema validation.
  #
  # This class represents a compiled JSON Schema and provides methods for validating JSON instances against it.
  #
  # ### Usage
  #
  # ```
  # require "json_schemer"
  #
  # # Create a schema
  # schema = JsonSchemer.schema(%q({
  #   "type": "object",
  #   "required": ["name", "email"],
  #   "properties": {
  #     "name": {"type": "string", "minLength": 1},
  #     "email": {"type": "string"},
  #     "age": {"type": "integer", "minimum": 0}
  #   }
  # }))
  #
  # # Validate data
  # valid_data = JSON.parse(%q({"name": "John", "email": "john@example.com", "age": 30}))
  # schema.valid?(valid_data) # => true
  #
  # invalid_data = JSON.parse(%q({"name": "", "age": -5}))
  # schema.valid?(invalid_data) # => false
  # ```
  class Schema
    include Output

    # Context struct for validation state
    class Context
      property instance : JSON::Any
      property dynamic_scope : Array(Schema)
      property adjacent_results : Hash(Keyword.class, Result)?
      property short_circuit : Bool
      property access_mode : String?

      def initialize(
        @instance : JSON::Any,
        @dynamic_scope : Array(Schema) = [] of Schema,
        @adjacent_results : Hash(Keyword.class, Result)? = nil,
        @short_circuit : Bool = false,
        @access_mode : String? = nil,
      )
      end

      def original_instance(instance_location : Location::Node) : JSON::Any
        # Optimized traversal: extract tokens directly from Location::Node
        # to avoid string construction (Location.resolve) and parsing (Hana::Pointer.parse).
        tokens = [] of String
        current = instance_location
        while name = current.name
          tokens << name
          current = current.parent
          break unless current
        end

        result = instance

        # Tokens are collected in reverse order (leaf -> root), so iterate in reverse (root -> leaf)
        tokens.reverse_each do |token|
          case result.raw
          when Array
            result = result.as_a[token.to_i]
          when Hash
            result = result.as_h[token]
          end
        end
        result
      end
    end

    # Class constants for keyword classes
    SCHEMA_KEYWORD_CLASS     = Draft202012::Vocab::Core::SchemaKeyword
    VOCABULARY_KEYWORD_CLASS = Draft202012::Vocab::Core::Vocabulary
    ID_KEYWORD_CLASS         = Draft202012::Vocab::Core::Id
    UNKNOWN_KEYWORD_CLASS    = Draft202012::Vocab::Core::UnknownKeyword
    NOT_KEYWORD_CLASS        = Draft202012::Vocab::Applicator::Not
    PROPERTIES_KEYWORD_CLASS = Draft202012::Vocab::Applicator::Properties

    property! base_uri : URI?
    property! meta_schema : Schema | String | Nil

    getter! root : Schema?
    getter! configuration : Configuration?
    getter! parsed : Hash(String, Keyword)?

    getter value : JSON::Any
    getter parent : Schema | Keyword | Nil
    getter keyword : String = ""
    getter location : Location::Node

    setter keywords : Hash(String, Keyword.class)?
    setter keyword_order : Hash(String, Int32)?

    def keywords : Hash(String, Keyword.class)
      @keywords ||= begin
        meta = resolved_meta_schema
        if meta.is_a?(Schema) && meta != self
          meta.keywords
        else
          Draft202012::Vocab::ALL
        end
      end
    end

    def keyword_order : Hash(String, Int32)
      @keyword_order ||= begin
        meta = resolved_meta_schema
        if meta.is_a?(Schema) && meta != self
          meta.keyword_order
        else
          {} of String => Int32 # Default order
        end
      end
    end

    @resources : NamedTuple(lexical: Resources, dynamic: Resources)?
    @absolute_keyword_location : String?
    @schema_pointer : String?
    @escaped_keyword : String?
    @ref_resolver : Proc(URI, JSONHash?)?
    @regexp_resolver : Proc(String, Regex?)?
    @needs_adjacent_results : Bool = false

    # Initializes a new `Schema`.
    #
    # Generally, you should use `JsonSchemer.schema` instead of calling this directly.
    #
    # - `value`: The schema definition (JSON::Any, Hash, Bool, etc.).
    # - `parent`: The parent schema or keyword (for context).
    # - `root`: The root schema.
    # - `keyword`: The keyword associated with this schema in the parent.
    # - `configuration`: Configuration options.
    # - `base_uri`: Base URI for resolving references.
    # - `meta_schema`: Meta-schema to use.
    # - `vocabulary`: Vocabulary configuration.
    # - `format`: Enable format assertions (default: false).
    # - `formats`: Custom format validators.
    # - `content_encodings`: Custom content encoding validators.
    # - `content_media_types`: Custom content media type validators.
    # - `ref_resolver`: Resolver for external references.
    # - `regexp_resolver`: Resolver for regex patterns.
    # - `output_format`: Default output format.
    # - `access_mode`: "read" or "write" mode.
    def initialize(
      value : JSON::Any | JSONHash | Bool,
      parent : Schema | Keyword | Nil = nil,
      root : Schema? = nil,
      keyword : String? = nil,
      configuration : Configuration? = nil,
      base_uri : URI? = nil,
      meta_schema : Schema | String | Nil = nil,
      vocabulary : Hash(String, Bool)? = nil,
      format : Bool? = nil,
      formats : Hash(String, Format::FormatValidator)? = nil,
      content_encodings : Hash(String, Content::ContentEncodingValidator)? = nil,
      content_media_types : Hash(String, Content::ContentMediaTypeValidator)? = nil,
      keywords_config : Hash(String, Proc(JSON::Any, JSON::Any, String, Keyword, Bool | Array(String)))? = nil,
      insert_property_defaults : Bool = false,
      property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)? = nil,
      ref_resolver : Proc(URI, JSONHash?) | String | Nil = nil,
      regexp_resolver : Proc(String, Regex?) | String | Nil = nil,
      output_format : String? = nil,
      resolve_enumerators : Bool? = nil,
      access_mode : String? = nil,
    )
      @location = if parent
                    kw = keyword || ""
                    if !kw.empty?
                      parent.location.join(kw)
                    else
                      parent.location
                    end
                  else
                    Location.root
                  end

      # Convert value to JSON::Any
      @value = case value
               when JSON::Any
                 value.clone
               when Bool
                 JSON::Any.new(value)
               else
                 JSON::Any.new(value.transform_values { |v| v.clone })
               end

      @parent = parent
      @root = root || self
      @keyword = keyword || ""

      # Use parent configuration as base if parent exists
      base_config = if parent.is_a?(Schema)
                      parent.configuration
                    elsif parent.is_a?(Keyword)
                      parent.root.configuration
                    else
                      configuration || JsonSchemer.configuration
                    end

      config = Configuration.new(
        base_uri: base_uri || base_config.base_uri,
        meta_schema: meta_schema || base_config.meta_schema,
        vocabulary: vocabulary || base_config.vocabulary,
        format: format.nil? ? base_config.format : format,
        formats: formats || base_config.formats,
        content_encodings: content_encodings || base_config.content_encodings,
        content_media_types: content_media_types || base_config.content_media_types,
        keywords: keywords_config || base_config.keywords,
        insert_property_defaults: insert_property_defaults,
        property_default_resolver: property_default_resolver || base_config.property_default_resolver,
        ref_resolver: ref_resolver || base_config.ref_resolver,
        regexp_resolver: regexp_resolver || base_config.regexp_resolver,
        output_format: output_format || base_config.output_format,
        resolve_enumerators: resolve_enumerators.nil? ? base_config.resolve_enumerators : resolve_enumerators,
        access_mode: access_mode || base_config.access_mode
      )
      @configuration = config

      @base_uri = config.base_uri
      @meta_schema = config.meta_schema

      # Keywords will be initialized during parsing (if processing a meta-schema)
      # or inherited from the meta-schema later (if processing a standard schema).
      @keywords = nil
      @keyword_order = nil

      @parsed = {} of String => Keyword
      parse
      @needs_adjacent_results = parsed.keys.any? { |k| ADJACENT_CONSUMERS.includes?(k) }
    end

    def schema : Schema
      self
    end

    ADJACENT_CONSUMERS = {
      "additionalProperties",
      "items",
      "then",
      "else",
      "maxContains",
      "minContains",
      "unevaluatedProperties",
      "unevaluatedItems",
      "contentMediaType",
      "contentSchema",
    }

    # Validates an instance against the schema and returns true if valid.
    #
    # The instance can be a `JSON::Any`, `Hash`, `Array`, or primitive types.
    #
    # ```
    # schema = JsonSchemer.schema(%q({"type": "integer"}))
    # schema.valid?(10)   # => true
    # schema.valid?("10") # => false
    # ```
    def valid?(
      instance,
      resolve_enumerators : Bool? = nil,
      access_mode : String? = nil,
    ) : Bool
      validate(
        instance,
        output_format: "flag",
        resolve_enumerators: resolve_enumerators.nil? ? configuration.resolve_enumerators : resolve_enumerators,
        access_mode: access_mode || configuration.access_mode
      )["valid"].as_bool
    end

    # Validates an instance against the schema and returns the validation result.
    #
    # The structure of the result depends on the `output_format`.
    #
    # * "flag": `{"valid" => true/false}`
    # * "basic": Includes a list of errors.
    # * "classic": Detailed hierarchical error reporting (default).
    #
    # ```
    # schema = JsonSchemer.schema(%q({"type": "integer"}))
    # result = schema.validate("invalid")
    # puts result["valid"]  # => false
    # puts result["errors"] # => Array of errors
    # ```
    def validate(
      instance,
      output_format : String? = nil,
      resolve_enumerators : Bool? = nil,
      access_mode : String? = nil,
    ) : Hash(String, JSON::Any)
      resolved_output_format = output_format || configuration.output_format
      # Note: resolve_enumerators is accepted for API compatibility but is a no-op in Crystal.
      # Crystal does not have Ruby's lazy Enumerator type, so there is nothing to resolve.
      resolved_access_mode = access_mode || configuration.access_mode

      # Convert instance to JSON::Any
      json_instance = case instance
                      when JSON::Any
                        instance
                      when Hash
                        JSON.parse(instance.to_json)
                      when Array
                        JSON.parse(instance.to_json)
                      when String, Number, Bool, Nil
                        JSON::Any.new(instance)
                      else
                        JSON.parse(instance.to_json)
                      end

      instance_location = Location.root
      context = Context.new(
        json_instance,
        [] of Schema,
        nil,
        resolved_output_format == "flag" && !configuration.insert_property_defaults,
        resolved_access_mode
      )

      result = validate_instance(json_instance, instance_location, context)

      # Insert property defaults if configured
      insert_defaults = configuration.insert_property_defaults
      if insert_defaults
        defaults_inserted = if pdr = configuration.property_default_resolver
                              result.insert_property_defaults(context) { |value, property, results| pdr.call(value, property, results) }
                            else
                              result.insert_property_defaults(context)
                            end

        if defaults_inserted
          # Re-validate after inserting defaults
          context = Context.new(
            json_instance,
            [] of Schema,
            nil,
            resolved_output_format == "flag",
            resolved_access_mode
          )
          result = validate_instance(json_instance, instance_location, context)
        end
      end

      result.output(resolved_output_format)
    end

    # Validate instance (internal)
    def validate_instance(instance : JSON::Any, instance_location : Location::Node, context : Context) : Result
      context.dynamic_scope.push(self)
      original_adjacent_results = context.adjacent_results

      adjacent_results = if @needs_adjacent_results
                           context.adjacent_results = {} of Keyword.class => Result
                         else
                           context.adjacent_results = nil
                         end

      short_circuit = context.short_circuit

      begin
        # Handle boolean schemas
        if value.raw == false
          return result(instance, instance_location, location, false)
        end
        if value.raw == true || (value.raw.is_a?(Hash) && value.as_h.empty?)
          return result(instance, instance_location, location, true)
        end

        valid = true
        nested = [] of Result

        parsed.each_value do |keyword_instance|
          keyword_result = keyword_instance.validate(instance, instance_location, context)
          next unless keyword_result

          valid = valid && keyword_result.valid
          return result(instance, instance_location, location, false) if short_circuit && !valid
          nested << keyword_result
          adjacent_results[keyword_instance.class] = keyword_result if adjacent_results
        end

        result(instance, instance_location, location, valid, nested)
      ensure
        context.dynamic_scope.pop
        context.adjacent_results = original_adjacent_results
      end
    end

    # Get schema pointer
    def schema_pointer : String
      @schema_pointer ||= if p = @parent
                            if kw = @keyword
                              "#{p.schema_pointer}/#{Location.escape_json_pointer_token(kw)}"
                            else
                              p.schema_pointer
                            end
                          else
                            ""
                          end
    end

    # Absolute keyword location
    def absolute_keyword_location : String
      @absolute_keyword_location ||= begin
        buri = base_uri
        frag = buri.fragment
        if @parent.nil? || (!@parent.is_a?(Schema) || @parent.as(Schema).base_uri != buri) && (frag.nil? || frag.empty?)
          uri = buri.dup
          uri.fragment = ""
          uri.to_s
        elsif kw = @keyword
          if p = @parent
            "#{p.absolute_keyword_location}/#{fragment_encode(Location.escape_json_pointer_token(kw))}"
          else
            ""
          end
        else
          if p = @parent
            p.absolute_keyword_location
          else
            ""
          end
        end
      end
    end

    # Error key
    def error_key : String
      "^"
    end

    # Error message
    def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
      if value.raw == false && @parent.responds_to?(:false_schema_error)
        @parent.as(Keyword).false_schema_error(formatted_instance_location, details)
      else
        "value at #{formatted_instance_location} does not match schema"
      end
    end

    # x-error support
    def x_error : String?
      parsed["x-error"]?.try do |xerr|
        if xerr.is_a?(Keyword)
          xerr.as(Draft202012::Vocab::Core::XError).message(error_key)
        end
      end
    end

    # Get resources
    def resources : NamedTuple(lexical: Resources, dynamic: Resources)
      @resources ||= {lexical: Resources.new, dynamic: Resources.new}
    end

    # Resolves a reference from the current schema's context.
    #
    # The reference is resolved relative to the schema's base URI.
    #
    # ```
    # # Given a schema at "http://example.com/schema.json"
    # subschema = schema.ref("#/definitions/user")
    # external_schema = schema.ref("other_schema.json")
    # ```
    def ref(ref_value : String) : Schema
      root.resolve_ref(base_uri.resolve(URI.parse(ref_value)))
    end

    # Resolve a reference URI
    def resolve_ref(uri : URI) : Schema
      pointer = ""
      frag = uri.fragment
      if frag && Format.valid_json_pointer?(frag)
        pointer = URI.decode(frag)
        uri = uri.dup
        uri.fragment = nil
      end

      lexical = resources[:lexical]
      schema_result = lexical[uri]

      if schema_result.nil? && uri.fragment.nil?
        empty_uri = uri.dup
        empty_uri.fragment = ""
        schema_result = lexical[empty_uri]
      end

      unless schema_result
        location_id = uri.fragment
        uri_copy = uri.dup
        uri_copy.fragment = nil

        resolved = ref_resolver.call(uri_copy)

        # Fallback to built-in meta-schemas if ref_resolver returns nil
        if resolved.nil?
          meta_callable = JsonSchemer::META_SCHEMA_CALLABLES_BY_BASE_URI_STR[uri_copy.to_s]?
          if meta_callable
            schema_result = meta_callable.call
          else
            raise InvalidRefResolution.new(uri.to_s)
          end
        else
          remote = JsonSchemer.schema(
            resolved,
            base_uri: uri_copy,
            meta_schema: resolved_meta_schema,
            ref_resolver: ref_resolver,
            regexp_resolver: regexp_resolver,
            formats: configuration.formats,
            content_encodings: configuration.content_encodings,
            content_media_types: configuration.content_media_types
          )

          remote_uri = remote.base_uri.dup
          remote_uri.fragment = location_id if location_id
          schema_result = remote.resources[:lexical].fetch(remote_uri)
        end
      end

      # Navigate pointer
      if !pointer.empty?
        begin
          tokens = Hana::Pointer.parse(pointer)
          current = schema_result
          tokens.each do |token|
            case current
            when Schema
              kw = current.parsed[token]?
              raise InvalidRefPointer.new(pointer) unless kw
              current = kw
            when Keyword
              current = current.fetch(token)
            else
              raise InvalidRefPointer.new(pointer)
            end
          end
          schema_result = current
        rescue e : KeyError | IndexError | ArgumentError
          raise InvalidRefPointer.new(pointer)
        end
      end

      # Unwrap to schema if needed
      if schema_result.is_a?(Keyword)
        ps = schema_result.parsed_schema
        raise InvalidRefPointer.new(pointer) unless ps
        schema_result = ps
      end

      raise InvalidRefPointer.new(pointer) unless schema_result.is_a?(Schema)
      schema_result
    end

    # Resolve regexp pattern
    def resolve_regexp(pattern : String) : Regex
      regexp_resolver.call(pattern) || raise InvalidRegexpResolution.new(pattern)
    end

    # Bundles the schema and its dependencies into a single JSON object.
    #
    # Resolves external references and embeds them into the schema using `$defs` (or `definitions`).
    # This is useful for creating self-contained schemas.
    #
    # ```
    # bundled_json = schema.bundle
    # File.write("bundled.json", bundled_json.to_json)
    # ```
    def bundle : JSON::Any
      return value unless value.as_h?

      meta = resolved_meta_schema
      id_keyword = meta.id_keyword
      defs_keyword = meta.defs_keyword

      compound_document = value.as_h.dup
      compound_document[id_keyword] = JSON::Any.new(base_uri.to_s)
      compound_document["$schema"] = JSON::Any.new(meta.base_uri.to_s)

      embedded_resources = if compound_document.has_key?(defs_keyword)
                             compound_document[defs_keyword].as_h.dup
                           else
                             {} of String => JSON::Any
                           end
      compound_document[defs_keyword] = JSON::Any.new(embedded_resources)

      kws = meta.keywords
      ref_keyword_class = kws ? kws["$ref"]? : nil
      if ref_keyword_class && ref_keyword_class.exclusive? && compound_document.has_key?("$ref")
        all_of = if compound_document.has_key?("allOf")
                   compound_document["allOf"].as_a.dup
                 else
                   [] of JSON::Any
                 end
        ref_val = compound_document.delete("$ref")
        if ref_val
          all_of << JSON::Any.new({"$ref" => ref_val})
        end
        compound_document["allOf"] = JSON::Any.new(all_of)
      end

      queue = Deque(Schema | Keyword | Hash(String, Keyword) | Array(Schema)).new
      queue << self

      while !queue.empty?
        item = queue.shift

        case item
        when Schema
          queue << item.parsed
        when Keyword
          is_ref = false
          ref_id = ""
          ref_schema_root = nil

          if item.is_a?(Draft202012::Vocab::Core::Ref)
            is_ref = true
            uri = item.ref_uri.dup
            uri.fragment = nil
            ref_id = uri.to_s
            ref_schema_root = item.ref_schema.root
          elsif item.is_a?(Draft202012::Vocab::Core::DynamicRef)
            is_ref = true
            uri = item.ref_uri.dup
            uri.fragment = nil
            ref_id = uri.to_s
            ref_schema_root = item.ref_schema.root
          end

          if is_ref && ref_schema_root
            if ref_schema_root != root && !embedded_resources.has_key?(ref_id)
              embedded_resource = ref_schema_root.value.as_h.dup
              embedded_resource[id_keyword] = JSON::Any.new(ref_id)
              embedded_resource["$schema"] = JSON::Any.new(ref_schema_root.resolved_meta_schema.base_uri.to_s)
              embedded_resources[ref_id] = JSON::Any.new(embedded_resource)

              queue << ref_schema_root
            end
          else
            p = item.parsed
            case p
            when Schema
              queue << p
            when Array(Schema)
              p.each { |subschema| queue << subschema }
            when Hash(String, Schema)
              p.each_value { |subschema| queue << subschema }
            end
          end
        when Hash(String, Keyword)
          item.each_value { |v| queue << v }
        when Array(Schema)
          item.each { |v| queue << v }
        end
      end

      JSON::Any.new(compound_document)
    end

    # Get ref resolver proc
    def ref_resolver : Proc(URI, JSONHash?)
      @ref_resolver ||= case configuration.ref_resolver
                        when String
                          if configuration.ref_resolver == "net/http"
                            resolver = CachedRefResolver.new(&NET_HTTP_REF_RESOLVER)
                            resolver.to_proc
                          else
                            DEFAULT_REF_RESOLVER
                          end
                        when Proc(URI, JSONHash?)
                          configuration.ref_resolver.as(Proc(URI, JSONHash?))
                        else
                          DEFAULT_REF_RESOLVER
                        end
    end

    # Get regexp resolver proc
    def regexp_resolver : Proc(String, Regex?)
      @regexp_resolver ||= case configuration.regexp_resolver
                           when "ecma"
                             resolver = CachedRegexpResolver.new(&ECMA_REGEXP_RESOLVER)
                             resolver.to_proc
                           when "ruby"
                             resolver = CachedRegexpResolver.new(&RUBY_REGEXP_RESOLVER)
                             resolver.to_proc
                           when Proc(String, Regex?)
                             configuration.regexp_resolver.as(Proc(String, Regex?))
                           else
                             resolver = CachedRegexpResolver.new(&RUBY_REGEXP_RESOLVER)
                             resolver.to_proc
                           end
    end

    # Fetch format validator
    def fetch_format(format_name : String) : Format::FormatValidator?
      configuration.formats[format_name]? ||
        begin
          meta = resolved_meta_schema
          # Prevent infinite recursion: don't look in meta_schema if it's the same as self
          if meta != self && meta.is_a?(Schema)
            meta.fetch_format(format_name)
          else
            nil
          end
        end
    end

    # Fetch content encoding
    def fetch_content_encoding(encoding : String) : Content::ContentEncodingValidator?
      configuration.content_encodings[encoding]? ||
        begin
          meta = resolved_meta_schema
          if meta != self && meta.is_a?(Schema)
            meta.fetch_content_encoding(encoding)
          else
            nil
          end
        end
    end

    # Fetch content media type
    def fetch_content_media_type(media_type : String) : Content::ContentMediaTypeValidator?
      configuration.content_media_types[media_type]? ||
        begin
          meta = resolved_meta_schema
          if meta != self && meta.is_a?(Schema)
            meta.fetch_content_media_type(media_type)
          else
            nil
          end
        end
    end

    # ID keyword name
    def id_keyword : String
      keywords.has_key?("$id") ? "$id" : "id"
    end

    # Defs keyword name
    def defs_keyword : String
      keywords.has_key?("$defs") ? "$defs" : "definitions"
    end

    # Resolved meta schema
    def resolved_meta_schema : Schema
      case @meta_schema
      when Schema
        @meta_schema.as(Schema)
      else
        JsonSchemer.draft202012
      end
    end

    # Inspect
    def inspect(io : IO) : Nil
      io << "#<" << self.class.name
      io << " @value=" << @value.inspect
      io << " @keyword=" << @keyword.inspect
      io << ">"
    end

    private def parse
      val = value
      @parsed = {} of String => Keyword

      # 1. Parse $schema (sets meta_schema property)
      if val.raw.is_a?(Hash) && val.as_h.has_key?("$schema")
        parsed["$schema"] = SCHEMA_KEYWORD_CLASS.new(val.as_h["$schema"], self, "$schema")
      elsif meta_schema.is_a?(String)
        SCHEMA_KEYWORD_CLASS.new(JSON::Any.new(meta_schema.as(String)), self, "$schema")
      end

      # 2. Parse $vocabulary (sets @keywords property)
      if val.raw.is_a?(Hash) && val.as_h.has_key?("$vocabulary")
        parsed["$vocabulary"] = VOCABULARY_KEYWORD_CLASS.new(val.as_h["$vocabulary"], self, "$vocabulary")
      elsif vocab = configuration.vocabulary
        VOCABULARY_KEYWORD_CLASS.new(JSON::Any.new(vocab.transform_values { |v| JSON::Any.new(v) }), self, "$vocabulary")
      end

      # 3. Determine lookup table for remaining keys
      meta = resolved_meta_schema
      lookup_keywords = meta.keywords
      lookup_keyword_order = meta.keyword_order

      # 4. Handle root $id specially
      ref_kw = lookup_keywords["$ref"]?
      exclusive_ref = val.raw.is_a?(Hash) && val.as_h.has_key?("$ref") && ref_kw && ref_kw.responds_to?(:exclusive?) && ref_kw.exclusive?

      if root == self && (!val.raw.is_a?(Hash) || !val.as_h.has_key?(meta.id_keyword) || exclusive_ref)
        ID_KEYWORD_CLASS.new(JSON::Any.new(base_uri.to_s), self, meta.id_keyword)
      end

      # 5. Parse remaining keywords
      if exclusive_ref && val.raw.is_a?(Hash)
        parsed["$ref"] = lookup_keywords["$ref"].new(val.as_h["$ref"], self, "$ref")
        dkw = meta.defs_keyword
        if val.as_h.has_key?(dkw) && lookup_keywords.has_key?(dkw)
          parsed[dkw] = lookup_keywords[dkw].new(val.as_h[dkw], self, dkw)
        end
      elsif val.raw.is_a?(Hash)
        # Sort by keyword order from meta-schema
        last = lookup_keywords.size
        sorted_keys = val.as_h.keys.sort_by! { |k| lookup_keyword_order[k]? || last }

        sorted_keys.each do |key|
          next if parsed.has_key?(key)
          kval = val.as_h[key]

          klass = if configuration.format && key == "format"
                    Draft202012::Vocab::FormatAssertion::Format
                  else
                    lookup_keywords[key]? || UNKNOWN_KEYWORD_CLASS
                  end

          parsed[key] = klass.new(kval, self, key)
        end
      end

      # Warmup caches
      parsed.each_value(&.after_schema_initialize)
    end
  end
end
