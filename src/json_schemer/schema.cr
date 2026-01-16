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
      property adjacent_results : Hash(Keyword.class, Result)
      property short_circuit : Bool
      property access_mode : String?

      def initialize(
        @instance : JSON::Any,
        @dynamic_scope : Array(Schema) = [] of Schema,
        @adjacent_results : Hash(Keyword.class, Result) = {} of Keyword.class => Result,
        @short_circuit : Bool = false,
        @access_mode : String? = nil,
      )
      end

      def original_instance(instance_location : Location::Node) : JSON::Any
        path = Location.resolve(instance_location)
        tokens = Hana::Pointer.parse(path)

        result = instance
        tokens.each do |token|
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

    @base_uri : URI?
    @meta_schema : (Schema | String)?
    @keywords : Hash(String, Keyword.class)?
    @keyword_order : Hash(String, Int32)?
    @value : JSON::Any?
    @root : Schema?
    @configuration : Configuration?
    @parsed : Hash(String, Keyword)?

    def base_uri : URI
      @base_uri.not_nil!
    end

    def base_uri=(value : URI)
      @base_uri = value
    end

    def meta_schema : Schema | String
      @meta_schema.not_nil!
    end

    def meta_schema=(value : Schema | String)
      @meta_schema = value
    end

    def keywords : Hash(String, Keyword.class)
      @keywords.not_nil!
    end

    def keywords=(value : Hash(String, Keyword.class))
      @keywords = value
    end

    def keyword_order : Hash(String, Int32)
      @keyword_order.not_nil!
    end

    def keyword_order=(value : Hash(String, Int32))
      @keyword_order = value
    end

    def value : JSON::Any
      @value.not_nil!
    end

    getter parent : Schema | Keyword | Nil

    def root : Schema
      @root.not_nil!
    end

    def configuration : Configuration
      @configuration.not_nil!
    end

    def parsed : Hash(String, Keyword)
      @parsed.not_nil!
    end

    @keyword : String = ""

    def keyword : String
      @keyword
    end

    @resources : NamedTuple(lexical: Resources, dynamic: Resources)?
    @absolute_keyword_location : String?
    @schema_pointer : String?
    @escaped_keyword : String?
    @ref_resolver : Proc(URI, JSONHash?)?
    @regexp_resolver : Proc(String, Regex?)?
    @root_keyword_location : Location::Node?

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
      keywords_config : Hash(String, Proc(JSON::Any, JSON::Any, String, Bool | Array(String)))? = nil,
      before_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil))? = nil,
      after_property_validation : Array(Proc(JSON::Any, String, JSON::Any, JSON::Any, Nil))? = nil,
      insert_property_defaults : Bool | Symbol = false,
      property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)? = nil,
      ref_resolver : Proc(URI, JSONHash?) | String | Nil = nil,
      regexp_resolver : Proc(String, Regex?) | String | Nil = nil,
      output_format : String? = nil,
      resolve_enumerators : Bool? = nil,
      access_mode : String? = nil,
    )
      # Convert value to JSON::Any
      @value = case value
               when JSON::Any
                 deep_stringify_keys(value)
               when Bool
                 JSON::Any.new(value)
               else
                 deep_stringify_keys(JSON::Any.new(value.transform_values { |v| v }))
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
        before_property_validation: before_property_validation || base_config.before_property_validation,
        after_property_validation: after_property_validation || base_config.after_property_validation,
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
    end

    def schema : Schema
      self
    end

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
      resolved_resolve_enumerators = resolve_enumerators.nil? ? configuration.resolve_enumerators : resolve_enumerators
      resolved_access_mode = access_mode || configuration.access_mode
      # Convert instance to JSON::Any
      json_instance = case instance
                      when JSON::Any
                        deep_stringify_keys(instance)
                      when Hash
                        deep_stringify_keys(JSON.parse(instance.to_json))
                      when Array
                        deep_stringify_keys(JSON.parse(instance.to_json))
                      when String, Number, Bool, Nil
                        JSON::Any.new(instance)
                      else
                        JSON.parse(instance.to_json)
                      end

      instance_location = root_keyword_location
      keyword_location = root_keyword_location
      context = Context.new(
        json_instance,
        [] of Schema,
        {} of Keyword.class => Result,
        resolved_output_format == "flag",
        resolved_access_mode
      )

      result = validate_instance(json_instance, instance_location, keyword_location, context)
      result.output(resolved_output_format)
    end

    # Validate instance (internal)
    def validate_instance(instance : JSON::Any, instance_location : Location::Node, keyword_location : Location::Node, context : Context) : Result
      context.dynamic_scope.push(self)
      original_adjacent_results = context.adjacent_results
      adjacent_results = context.adjacent_results = {} of Keyword.class => Result
      short_circuit = context.short_circuit

      begin
        # Handle boolean schemas
        if value.raw == false
          return result(instance, instance_location, keyword_location, false)
        end
        if value.raw == true || (value.raw.is_a?(Hash) && value.as_h.empty?)
          return result(instance, instance_location, keyword_location, true)
        end

        valid = true
        nested = [] of Result

        parsed.each do |kw, keyword_instance|
          keyword_result = keyword_instance.validate(instance, instance_location, join_location(keyword_location, kw), context)
          next unless keyword_result

          valid = valid && keyword_result.valid
          return result(instance, instance_location, keyword_location, false) if short_circuit && !valid
          nested << keyword_result
          adjacent_results[keyword_instance.class] = keyword_result
        end

        result(instance, instance_location, keyword_location, valid, nested)
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
        if @parent.nil? || (!@parent.is_a?(Schema) || @parent.as(Schema).base_uri != buri) && (buri.fragment.nil? || buri.fragment.not_nil!.empty?)
          uri = buri.dup
          uri.fragment = ""
          uri.to_s
        elsif kw = @keyword
          "#{@parent.not_nil!.absolute_keyword_location}/#{fragment_encode(Location.escape_json_pointer_token(kw))}"
        else
          @parent.not_nil!.absolute_keyword_location
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
      if uri.fragment && Format.valid_json_pointer?(uri.fragment.not_nil!)
        pointer = URI.decode(uri.fragment.not_nil!)
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

      ref_keyword_class = meta.keywords["$ref"]?
      if ref_keyword_class && ref_keyword_class.exclusive? && compound_document.has_key?("$ref")
        all_of = if compound_document.has_key?("allOf")
                   compound_document["allOf"].as_a.dup
                 else
                   [] of JSON::Any
                 end
        all_of << JSON::Any.new({"$ref" => compound_document.delete("$ref").not_nil!})
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
              p.each { |s| queue << s }
            when Hash(String, Schema)
              p.each_value { |s| queue << s }
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
      # Parse $schema first
      if val.raw.is_a?(Hash) && val.as_h.has_key?("$schema")
        parsed["$schema"] = SCHEMA_KEYWORD_CLASS.new(val.as_h["$schema"], self, "$schema")
      elsif meta_schema.is_a?(String)
        SCHEMA_KEYWORD_CLASS.new(JSON::Any.new(meta_schema.as(String)), self, "$schema")
      end

      # Parse $vocabulary
      if val.raw.is_a?(Hash) && val.as_h.has_key?("$vocabulary")
        parsed["$vocabulary"] = VOCABULARY_KEYWORD_CLASS.new(val.as_h["$vocabulary"], self, "$vocabulary")
      elsif vocab = configuration.vocabulary
        VOCABULARY_KEYWORD_CLASS.new(JSON::Any.new(vocab.transform_values { |v| JSON::Any.new(v) }), self, "$vocabulary")
      end

      # Parse $id for root
      if root == self && val.raw.is_a?(Hash)
        unless val.as_h.has_key?(resolved_meta_schema.id_keyword)
          ID_KEYWORD_CLASS.new(JSON::Any.new(base_uri.to_s), self, resolved_meta_schema.id_keyword)
        end
      end

      # If keywords are not set yet (no $vocabulary), inherit from meta-schema
      if @keywords.nil?
        meta = resolved_meta_schema
        # If meta-schema is self and keywords are not set, it means we are bootstrapping a meta-schema
        # that doesn't use $vocabulary (e.g. Draft 4/6/7 or custom).
        # In this case, we can't inherit. We rely on the defaults being set if it's a known meta-schema,
        # but here we are creating it.
        # For standard drafts, we provided vocabulary/keywords in configuration or they are built-in.
        if meta != self
          kw = meta.keywords.dup
          # Apply format assertion override if enabled
          if configuration.format && kw.has_key?("format")
            kw["format"] = Draft202012::Vocab::FormatAssertion::Format
          end
          @keywords = kw
          @keyword_order = meta.keyword_order
        else
          # Fallback for self-referencing meta-schema without $vocabulary
          # This should only happen for older drafts or broken schemas.
          # For Draft 2020-12, $vocabulary is present so keywords are set.
          # For older drafts, we use `vocabulary` option in singleton creation.
          if @keywords.nil?
            # Last resort fallback to empty or default?
            # For now, let's use Draft 2020-12 default if absolutely nothing else
            # But this might be wrong if it's a completely different schema.
            # Ideally this path is not taken for valid scenarios.
            @keywords = Draft202012::Vocab::ALL.dup
            @keyword_order = @keywords.not_nil!.keys.each_with_index.to_h { |k, i| {k, i} }
          end
        end
      end

      # Parse remaining keywords
      if val.raw.is_a?(Hash)
        # Sort by keyword order
        sorted_keys = val.as_h.keys.sort_by { |k| keyword_order[k]? || Int32::MAX }

        sorted_keys.each do |kw|
          next if parsed.has_key?(kw)
          kval = val.as_h[kw]
          klass = keywords[kw]? || UNKNOWN_KEYWORD_CLASS
          parsed[kw] = klass.new(kval, self, kw)
        end
      end
    end

    private def root_keyword_location : Location::Node
      @root_keyword_location ||= Location.root
    end
  end
end
