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

    # Context class for validation state.
    #
    # Context holds mutable state during validation including recursion depth,
    # dynamic scope for $dynamicRef resolution, and adjacent results for
    # unevaluated items/properties tracking.
    #
    # For high-throughput scenarios, reuse contexts by passing a pre-allocated
    # context to `Schema#validate`. Call `reset` between validations to clear state.
    #
    # ```
    # context = JsonSchemer::Schema::Context.new(JSON::Any.new(nil))
    #
    # # Reuse the context for multiple validations
    # schema1.validate(data1, context: context)
    # context.reset(JSON::Any.new(nil))
    # schema2.validate(data2, context: context)
    # ```
    class Context
      property instance : JSON::Any
      property dynamic_scope : Array(Schema)
      property adjacent_results : Hash(Keyword.class, Result)?
      property short_circuit : Bool
      property access_mode : String?
      property depth : Int32
      # Thread-safe discriminator recursion guard: tracks schema locations to skip
      # during discriminator <-> allOf validation to prevent infinite loops.
      # Stored on Context instead of keyword instances for fiber-safety.
      property discriminator_skip : Set(String)

      def initialize(
        @instance : JSON::Any,
        @dynamic_scope : Array(Schema) = [] of Schema,
        @adjacent_results : Hash(Keyword.class, Result)? = nil,
        @short_circuit : Bool = false,
        @access_mode : String? = nil,
        @depth : Int32 = 0,
        @discriminator_skip : Set(String) = Set(String).new,
      )
      end

      # Resets the context to a clean state for reuse.
      # This avoids allocation overhead by clearing existing collections
      # instead of creating new ones.
      #
      # Returns self for method chaining.
      def reset(
        @instance : JSON::Any,
        @short_circuit : Bool = false,
        @access_mode : String? = nil,
      ) : self
        @dynamic_scope.clear
        @adjacent_results = nil
        @depth = 0
        @discriminator_skip.clear
        self
      end
    end

    # JsonPointerUri struct for pointer result from URI fragment parsing.
    private struct JsonPointerUri
      property pointer : String
      property uri_without_fragment : URI

      def initialize(@pointer : String, @uri_without_fragment : URI)
      end

      def self.new(uri : URI)
        pointer = ""
        frag = uri.fragment
        if frag && Format.valid_json_pointer?(frag)
          pointer = URI.decode(frag)
          uri = uri.dup
          uri.fragment = nil
        end
        JsonPointerUri.new(pointer, uri)
      end
    end

    # Class constants for keyword classes
    SCHEMA_KEYWORD_CLASS     = Draft202012::Vocab::Core::SchemaKeyword
    VOCABULARY_KEYWORD_CLASS = Draft202012::Vocab::Core::Vocabulary
    ID_KEYWORD_CLASS         = Draft202012::Vocab::Core::Id
    UNKNOWN_KEYWORD_CLASS    = Draft202012::Vocab::Core::UnknownKeyword
    NOT_KEYWORD_CLASS        = Draft202012::Vocab::Applicator::Not
    PROPERTIES_KEYWORD_CLASS = Draft202012::Vocab::Applicator::Properties

    property base_uri : URI = URI.parse("")
    property meta_schema : Schema | String = ""

    getter! root : Schema?
    getter! configuration : Configuration?
    getter! parsed : Hash(String, Keyword)?

    getter value : JSON::Any
    getter parent : Schema | Keyword | Nil
    getter keyword : String = ""
    getter location : Location::Node

    setter keywords : Hash(String, Keyword.class)?
    setter keyword_order : Hash(String, Int32)?

    @lock = Mutex.new(protection: :reentrant)

    def keywords : Hash(String, Keyword.class)
      @keywords || @lock.synchronize do
        @keywords ||= begin
          meta = resolved_meta_schema
          if meta.is_a?(Schema) && meta != self
            meta.keywords
          else
            Draft202012::Vocab::ALL
          end
        end
      end
    end

    def keyword_order : Hash(String, Int32)
      @keyword_order || @lock.synchronize do
        @keyword_order ||= begin
          meta = resolved_meta_schema
          if meta.is_a?(Schema) && meta != self
            meta.keyword_order
          else
            {} of String => Int32 # Default order
          end
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
      insert_property_defaults : Bool? = nil,
      property_default_resolver : Proc(JSON::Any, String, Array(Tuple(Result, Bool)), Bool)? = nil,
      ref_resolver : Proc(URI, JSONHash?) | String | Nil = nil,
      regexp_resolver : Proc(String, Regex?) | String | Nil = nil,
      output_format : String? = nil,
      access_mode : String? = nil,
      max_depth : Int32? = nil,
      regexp_filter : Proc(String, Bool)? = nil,
    )
      # Step 1: Compute location in the schema tree
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

      # Step 2: Normalize value to JSON::Any
      @value = case value
               when JSON::Any
                 value
               when Bool
                 JSON::Any.new(value)
               else
                 JSON::Any.new(value.transform_values { |v| v })
               end

      @parent = parent
      @root = root || self
      @keyword = keyword || ""

      # Step 3: Resolve configuration (inherit from parent or use provided/global)
      base_config = if parent.is_a?(Schema)
                      parent.configuration
                    elsif parent.is_a?(Keyword)
                      parent.root.configuration
                    else
                      configuration || JsonSchemer.configuration
                    end

      # Step 4: Build merged configuration (explicit args override inherited values)
      config = base_config.dup_with(
        base_uri: base_uri.nil? ? UNSET : base_uri,
        meta_schema: meta_schema.nil? ? UNSET : meta_schema,
        vocabulary: vocabulary.nil? ? UNSET : vocabulary,
        format: format.nil? ? UNSET : format,
        formats: formats.nil? ? UNSET : formats,
        content_encodings: content_encodings.nil? ? UNSET : content_encodings,
        content_media_types: content_media_types.nil? ? UNSET : content_media_types,
        keywords: keywords_config.nil? ? UNSET : keywords_config,
        insert_property_defaults: insert_property_defaults.nil? ? UNSET : insert_property_defaults,
        property_default_resolver: property_default_resolver.nil? ? UNSET : property_default_resolver,
        ref_resolver: ref_resolver.nil? ? UNSET : ref_resolver,
        regexp_resolver: regexp_resolver.nil? ? UNSET : regexp_resolver,
        output_format: output_format.nil? ? UNSET : output_format,
        access_mode: access_mode.nil? ? UNSET : access_mode,
        max_depth: max_depth.nil? ? UNSET : max_depth,
        regexp_filter: regexp_filter.nil? ? UNSET : regexp_filter
      )
      @configuration = config

      @base_uri = config.base_uri
      @meta_schema = config.meta_schema

      # Keywords will be initialized during parsing (if processing a meta-schema)
      # or inherited from the meta-schema later (if processing a standard schema).
      @keywords = nil
      @keyword_order = nil

      # Step 5: Parse keywords and determine which need adjacent results
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
    # The instance must be a `JSON::Any` or a JSON `String`.
    #
    # For high-throughput scenarios, you can reuse a Context object by passing it
    # as the `context` parameter. This avoids allocation overhead for each validation.
    #
    # ```
    # schema = JsonSchemer.schema(%q({"type": "integer"}))
    # schema.valid?(JSON::Any.new(10_i64)) # => true
    # schema.valid?("10")                  # => true (parsed as 10)
    # schema.valid?("\"10\"")              # => false (parsed as "10")
    #
    # # High-throughput usage with context reuse
    # context = JsonSchemer::Schema::Context.new(JSON::Any.new(nil))
    # 1000.times do |i|
    #   context.reset(JSON::Any.new(i))
    #   schema.valid?(JSON::Any.new(i), context: context)
    # end
    # ```
    def valid?(
      instance : JSON::Any | String,
      access_mode : String? = nil,
      context : Context? = nil,
    ) : Bool
      validate(
        instance,
        output_format: "flag",
        access_mode: access_mode || configuration.access_mode,
        context: context,
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
    # For high-throughput scenarios, you can reuse a Context object by passing it
    # as the `context` parameter. This avoids allocation overhead for each validation.
    #
    # ```
    # schema = JsonSchemer.schema(%q({"type": "integer"}))
    #
    # # Standard usage (creates new context each time)
    # result = schema.validate("\"invalid\"")
    # puts result["valid"]  # => false
    # puts result["errors"] # => Array of errors
    #
    # # High-throughput usage (reuses context)
    # context = JsonSchemer::Schema::Context.new(JSON::Any.new(nil))
    # 1000.times do |i|
    #   context.reset(JSON::Any.new(i))
    #   schema.validate(JSON::Any.new(i), context: context)
    # end
    # ```
    def validate(
      instance : JSON::Any | String,
      output_format : String? = nil,
      access_mode : String? = nil,
      context : Context? = nil,
    ) : Hash(String, JSON::Any)
      resolved_output_format = output_format || configuration.output_format
      resolved_access_mode = access_mode || configuration.access_mode
      json_instance = if instance.is_a?(JSON::Any)
                        instance
                      else
                        JSON.parse(instance)
                      end
      instance_location = Location.root
      short_circuit = resolved_output_format == "flag" && !configuration.insert_property_defaults

      # Use provided context (reset it) or create a new one
      ctx = if provided_context = context
              provided_context.reset(json_instance, short_circuit, resolved_access_mode)
            else
              Context.new(
                json_instance,
                [] of Schema,
                nil,
                short_circuit,
                resolved_access_mode
              )
            end

      result = validate_instance(json_instance, instance_location, ctx)
      # Insert property defaults if configured
      insert_defaults = configuration.insert_property_defaults
      if insert_defaults
        defaults_inserted = if pdr = configuration.property_default_resolver
                              result.insert_property_defaults(ctx) { |value, property, results| pdr.call(value, property, results) }
                            else
                              result.insert_property_defaults(ctx)
                            end
        if defaults_inserted
          # Re-validate after inserting defaults
          ctx.reset(json_instance, resolved_output_format == "flag", resolved_access_mode)
          result = validate_instance(json_instance, instance_location, ctx)
        end
      end
      result.output(resolved_output_format)
    end

    # Validate instance (internal)
    def validate_instance(instance : JSON::Any, instance_location : Location::Node, context : Context) : Result
      if context.depth >= configuration.max_depth
        raise MaximumDepthExceeded.new(configuration.max_depth)
      end

      context.depth += 1
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
        # Per JSON Schema spec: empty object {} is equivalent to the `true` schema (matches everything)
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
        context.depth -= 1
        context.dynamic_scope.pop
        context.adjacent_results = original_adjacent_results
      end
    end

    # Get schema pointer
    def schema_pointer : String
      @schema_pointer || @lock.synchronize do
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
    end

    # Absolute keyword location
    def absolute_keyword_location : String
      @absolute_keyword_location || @lock.synchronize do
        @absolute_keyword_location ||= begin
          buri = base_uri
          frag = buri.fragment
          p = @parent
          if p.nil? || (!p.is_a?(Schema) || p.base_uri != buri) && (frag.nil? || frag.empty?)
            uri = buri.dup
            uri.fragment = ""
            uri.to_s
          elsif kw = @keyword
            "#{p.absolute_keyword_location}/#{fragment_encode(Location.escape_json_pointer_token(kw))}"
          else
            p.absolute_keyword_location
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
      @resources || @lock.synchronize do
        @resources ||= {lexical: Resources.new, dynamic: Resources.new}
      end
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
      json_pointer_uri = JsonPointerUri.new(uri)
      lexical = resources[:lexical]
      schema_result = lexical[json_pointer_uri.uri_without_fragment]
      if schema_result.nil?
        empty_uri = json_pointer_uri.uri_without_fragment.dup
        empty_uri.fragment = ""
        schema_result = lexical[empty_uri]
      end
      unless schema_result
        schema_result = fetch_remote_schema(json_pointer_uri.uri_without_fragment)
      end
      # Navigate pointer
      if !json_pointer_uri.pointer.empty?
        schema_result = navigate_json_pointer(schema_result, json_pointer_uri.pointer)
      end
      unwrap_to_schema(schema_result, json_pointer_uri.pointer)
    end

    # Resolve regexp pattern
    def resolve_regexp(pattern : String) : Regex
      config = configuration

      # Apply custom filter
      if filter = config.regexp_filter
        unless filter.call(pattern)
          raise RegexFilterViolation.new(pattern)
        end
      end

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

      # Step 1: Set up compound document with $id and $schema
      meta = resolved_meta_schema
      id_keyword = meta.id_keyword
      defs_keyword = meta.defs_keyword

      compound_document = value.as_h.dup
      compound_document[id_keyword] = JSON::Any.new(base_uri.to_s)
      compound_document["$schema"] = JSON::Any.new(meta.base_uri.to_s)

      # Step 2: Prepare embedded resources container (reuse existing $defs if present)
      embedded_resources = if compound_document.has_key?(defs_keyword)
                             compound_document[defs_keyword].as_h.dup
                           else
                             {} of String => JSON::Any
                           end
      compound_document[defs_keyword] = JSON::Any.new(embedded_resources)

      # Step 3: Handle exclusive $ref (older drafts) — wrap in allOf
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

      # Step 4: BFS traversal — walk the schema tree collecting external $ref targets
      queue = Deque(Schema | Keyword | Hash(String, Keyword) | Array(Schema)).new
      queue << self

      while !queue.empty?
        item = queue.shift

        case item
        when Schema
          queue << item.parsed
        when Keyword
          # Check if this keyword is a $ref or $dynamicRef pointing to an external schema
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
            # Embed the external schema if not already present
            if ref_schema_root != root && !embedded_resources.has_key?(ref_id)
              embedded_resource = ref_schema_root.value.as_h.dup
              embedded_resource[id_keyword] = JSON::Any.new(ref_id)
              embedded_resource["$schema"] = JSON::Any.new(ref_schema_root.resolved_meta_schema.base_uri.to_s)
              embedded_resources[ref_id] = JSON::Any.new(embedded_resource)

              queue << ref_schema_root
            end
          else
            # Not a ref — continue traversal into subschemas
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
      @ref_resolver || @lock.synchronize do
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
    end

    # Get regexp resolver proc
    def regexp_resolver : Proc(String, Regex?)
      @regexp_resolver || @lock.synchronize do
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
    end

    # Fetch format validator
    def fetch_format(format_name : String) : Format::FormatValidator?
      fetch_from_meta_chain(configuration.formats[format_name]?) { |meta| meta.fetch_format(format_name) }
    end

    # Fetch content encoding
    def fetch_content_encoding(encoding : String) : Content::ContentEncodingValidator?
      fetch_from_meta_chain(configuration.content_encodings[encoding]?) { |meta| meta.fetch_content_encoding(encoding) }
    end

    # Fetch content media type
    def fetch_content_media_type(media_type : String) : Content::ContentMediaTypeValidator?
      fetch_from_meta_chain(configuration.content_media_types[media_type]?) { |meta| meta.fetch_content_media_type(media_type) }
    end

    # Shared lookup pattern: return the local value if present, otherwise
    # walk up the meta-schema chain. Prevents infinite recursion by
    # stopping when the meta-schema is `self`.
    private def fetch_from_meta_chain(local, &)
      local || begin
        meta = resolved_meta_schema
        if meta != self && meta.is_a?(Schema)
          yield meta
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

    private def parse : Nil
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

    # Fetch a remote schema from a URI.
    # Falls back to built-in meta-schemas if ref_resolver returns nil.
    private def fetch_remote_schema(uri : URI) : Schema | Keyword | Nil
      location_id = uri.fragment
      uri_copy = uri.dup
      uri_copy.fragment = nil

      resolved = ref_resolver.call(uri_copy)

      # Fallback to built-in meta-schemas if ref_resolver returns nil
      if resolved.nil?
        meta_callable = JsonSchemer::META_SCHEMA_CALLABLES_BY_BASE_URI_STR[uri_copy.to_s]?
        if meta_callable
          return meta_callable.call
        else
          raise InvalidRefResolution.new(uri.to_s)
        end
      end

      remote = JsonSchemer.schema(
        resolved,
        base_uri: uri_copy,
        meta_schema: resolved_meta_schema,
        ref_resolver: ref_resolver,
        regexp_resolver: regexp_resolver,
        formats: configuration.formats,
        content_encodings: configuration.content_encodings,
        content_media_types: configuration.content_media_types,
        insert_property_defaults: configuration.insert_property_defaults,
        property_default_resolver: configuration.property_default_resolver
      )

      remote_uri = remote.base_uri.dup
      remote_uri.fragment = location_id if location_id
      remote.resources[:lexical].fetch(remote_uri)
    end

    # Navigate through Schema/Keyword using JSON pointer tokens.
    private def navigate_json_pointer(start : Schema | Keyword, pointer : String) : Schema | Keyword
      tokens = Hana::Pointer.parse(pointer)
      current : Schema | Keyword = start
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
      current
    rescue e : KeyError | IndexError | ArgumentError
      raise InvalidRefPointer.new(pointer)
    end

    # Unwrap a result to Schema if it's a Keyword.
    private def unwrap_to_schema(result : Schema | Keyword, pointer : String) : Schema
      if result.is_a?(Keyword)
        ps = result.parsed_schema
        raise InvalidRefPointer.new(pointer) unless ps
        result = ps
      end

      raise InvalidRefPointer.new(pointer) unless result.is_a?(Schema)
      result
    end
  end
end
