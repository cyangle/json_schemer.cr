module JsonSchemer
  # Result of validation
  class Result
    property source : Schema | Keyword
    property instance : JSON::Any
    property instance_location : Location::Node
    property keyword_location : Location::Node
    property valid : Bool
    property nested : Array(Result)?
    property type : String?
    property result_annotation : JSON::Any?
    property details : Hash(String, JSON::Any)?
    property ignore_nested : Bool
    property nested_key : String

    @resolved_instance_location : String?
    @resolved_keyword_location : String?
    @formatted_instance_location : String?
    @error : String?

    def initialize(
      @source : Schema | Keyword,
      @instance : JSON::Any,
      @instance_location : Location::Node,
      @keyword_location : Location::Node,
      @valid : Bool,
      @nested : Array(Result)? = nil,
      @type : String? = nil,
      @result_annotation : JSON::Any? = nil,
      @details : Hash(String, JSON::Any)? = nil,
      @ignore_nested : Bool = false,
      @nested_key : String = "errors",
    )
    end

    # Alias for compatibility - provides access to annotation value
    def annotation : JSON::Any?
      result_annotation
    end

    # Output in specified format
    def output(output_format : String) : Hash(String, JSON::Any)
      case output_format
      when "classic"
        classic
      when "flag"
        flag
      when "basic"
        basic
      when "detailed"
        detailed
      when "verbose"
        verbose
      else
        raise UnknownOutputFormat.new(output_format)
      end
    end

    # Get error message
    def error : String
      @error ||= begin
        custom_msg = source.x_error

        if custom_msg
          interpolate(custom_msg)
        else
          source.error(formatted_instance_location: formatted_instance_location, details: details)
        end
      end
    end

    private def interpolate(message : String) : String
      context = {
        "instance"                  => instance.raw.inspect,
        "instanceLocation"          => resolved_instance_location,
        "formattedInstanceLocation" => formatted_instance_location,
        "keywordValue"              => source.value.raw.inspect,
        "keywordLocation"           => resolved_keyword_location,
        "absoluteKeywordLocation"   => source.absolute_keyword_location,
        "details"                   => details.try(&.inspect) || "nil",
      }

      if d = details
        d.each do |k, v|
          context["details__#{k}"] = v.raw.inspect
        end
      end

      begin
        message % context
      rescue
        message
      end
    end

    # Output unit for basic/detailed/verbose formats
    def to_output_unit : Hash(String, JSON::Any)
      out = {
        "valid"                   => JSON::Any.new(valid),
        "keywordLocation"         => JSON::Any.new(resolved_keyword_location),
        "absoluteKeywordLocation" => JSON::Any.new(source.absolute_keyword_location),
        "instanceLocation"        => JSON::Any.new(resolved_instance_location),
      }

      if valid
        if ann = result_annotation
          out["annotation"] = ann
        end
      else
        out["error"] = JSON::Any.new(error)
      end

      out
    end

    # Classic error format
    def to_classic : Hash(String, JSON::Any)
      schema_obj = source.schema
      out = {
        "data"           => instance,
        "data_pointer"   => JSON::Any.new(resolved_instance_location),
        "schema"         => schema_obj.value,
        "schema_pointer" => JSON::Any.new(schema_obj.schema_pointer),
        "root_schema"    => schema_obj.root.value,
        "type"           => JSON::Any.new(type || classic_error_type),
      }
      out["error"] = JSON::Any.new(error)
      if det = details
        out["details"] = JSON::Any.new(det.transform_values { |v| v })
      end
      out
    end

    # Flag output format
    def flag : Hash(String, JSON::Any)
      {"valid" => JSON::Any.new(valid)}
    end

    # Basic output format
    def basic : Hash(String, JSON::Any)
      out = to_output_unit
      if n = nested
        unless n.empty?
          errors = [] of Hash(String, JSON::Any)
          collect_basic_errors(errors)
          out[nested_key] = JSON::Any.new(errors.map { |e| JSON::Any.new(e.transform_values { |v| v }) })
        end
      end
      out
    end

    protected def collect_basic_errors(errors : Array(Hash(String, JSON::Any)))
      if ignore_nested || nested.try(&.empty?) != false
        errors << to_output_unit
      elsif n = nested
        n.each do |result|
          if result.valid == valid
            result.collect_basic_errors(errors)
          end
        end
      end
    end

    # Detailed output format
    def detailed : Hash(String, JSON::Any)
      return to_output_unit if ignore_nested || nested.try(&.empty?) != false

      n = nested
      return to_output_unit unless n
      matching = n.select { |result| result.valid == valid }
      if matching.size == 1
        matching.first.detailed
      else
        out = to_output_unit
        unless matching.empty?
          out[nested_key] = JSON::Any.new(matching.map { |result| JSON::Any.new(result.detailed.transform_values { |v| v }) })
        end
        out
      end
    end

    # Verbose output format
    def verbose : Hash(String, JSON::Any)
      out = to_output_unit
      if n = nested
        unless n.empty?
          out[nested_key] = JSON::Any.new(n.map { |result| JSON::Any.new(result.verbose.transform_values { |v| v }) })
        end
      end
      out
    end

    # Classic output format (returns array for iteration compatibility)
    def classic : Hash(String, JSON::Any)
      result = {} of String => JSON::Any
      result["valid"] = JSON::Any.new(valid)

      unless valid
        errors = [] of Hash(String, JSON::Any)
        collect_classic_errors(errors)
        result["errors"] = JSON::Any.new(errors.map { |e| JSON::Any.new(e.transform_values { |v| v }) })
      end

      result
    end

    protected def collect_classic_errors(errors : Array(Hash(String, JSON::Any)))
      unless valid
        if ignore_nested || nested.try(&.empty?) != false
          errors << to_classic
        elsif n = nested
          added = false
          n.each do |result|
            if result.valid == valid
              result.collect_classic_errors(errors)
              added = true
            end
          end
          errors << to_classic unless added
        end
      end
    end

    # Classic errors as enumerable
    def each_classic_error(&)
      unless valid
        collect_and_yield_classic(self) { |e| yield e }
      end
    end

    private def collect_and_yield_classic(result : Result, &)
      if result.ignore_nested || result.nested.try(&.empty?) != false
        yield result.to_classic
      elsif n = result.nested
        added = false
        n.each do |nested_result|
          if nested_result.valid == result.valid
            collect_and_yield_classic(nested_result) { |e| yield e }
            added = true
          end
        end
        yield result.to_classic unless added
      end
    end

    private def resolved_instance_location : String
      @resolved_instance_location ||= Location.resolve(instance_location)
    end

    private def formatted_instance_location : String
      @formatted_instance_location ||= resolved_instance_location.empty? ? "root" : "`#{resolved_instance_location}`"
    end

    private def resolved_keyword_location : String
      @resolved_keyword_location ||= Location.resolve(keyword_location)
    end

    private def classic_error_type : String
      source.class.name.split("::").last.downcase
    end

    # Inserts default values from the result tree into the original instance.
    # Returns true if any defaults were inserted (indicating re-validation is needed).
    def insert_property_defaults(context : Schema::Context, &block : JSON::Any, String, Array(Tuple(Result, Bool)) -> Bool) : Bool
      # Store candidates: Key = {instance_pointer, property_name}, Value = List of {default_value, source_result, path_valid}
      candidates = Hash(Tuple(String, String), Array(Tuple(JSON::Any, Result, Bool))).new do |h, k|
        h[k] = [] of Tuple(JSON::Any, Result, Bool)
      end

      collect_property_defaults(context, candidates, valid)

      inserted = false

      candidates.each do |(instance_ptr, property), entries|
        # Check for value conflicts
        # We use strict equality for JSON values
        first_value = entries.first[0]
        conflict = entries.any? { |e| e[0] != first_value }

        unless conflict
          results = entries.map { |e| {e[1], e[2]} }

          if yield(first_value, property, results)
            if apply_default(context, instance_ptr, property, first_value)
              inserted = true
            end
          end
        end
      end

      inserted
    end

    def insert_property_defaults(context : Schema::Context) : Bool
      insert_property_defaults(context) { |_v, _p, _r| true }
    end

    protected def collect_property_defaults(context : Schema::Context, candidates : Hash(Tuple(String, String), Array(Tuple(JSON::Any, Result, Bool))), parent_valid : Bool)
      n = nested
      return unless n

      n.each do |child_result|
        # Skip NOT subschemas
        next if child_result.source.is_a?(Draft202012::Vocab::Applicator::Not)

        child_valid = parent_valid && child_result.valid

        if child_result.source.is_a?(Draft202012::Vocab::Applicator::Properties)
          properties_kw = child_result.source.as(Draft202012::Vocab::Applicator::Properties)

          if child_result.instance.raw.is_a?(Hash)
            instance_hash = child_result.instance.as_h
            # Resolve pointer once
            instance_ptr = Location.resolve(child_result.instance_location)

            properties_kw.schemas.each do |property, prop_schema|
              next if instance_hash.has_key?(property)

              default_kw = prop_schema.parsed["default"]?
              if default_kw.is_a?(Keyword)
                default_value = default_kw.value.clone
                candidates[{instance_ptr, property}] << {default_value, child_result, child_valid}
              end
            end
          end
        end

        # Recurse
        child_result.collect_property_defaults(context, candidates, child_valid)
      end
    end

    private def apply_default(context : Schema::Context, instance_ptr : String, property : String, value : JSON::Any) : Bool
      # 1. Update working copy
      target = navigate_instance_pointer(context.instance, instance_ptr)
      return false unless target && target.raw.is_a?(Hash)

      target_hash = target.as_h
      return false if target_hash.has_key?(property)

      target_hash[property] = value

      # 2. Update original instance
      if orig_ref = context.original_instance_ref
        begin
          orig_target = navigate_instance_pointer(orig_ref, instance_ptr)
          if orig_target && orig_target.raw.is_a?(Hash)
            orig_target.as_h[property] = value
          end
        rescue e : KeyError | IndexError
          # Ignore navigation errors
        end
      end

      true
    end

    # Navigate a JSON::Any instance using a string pointer
    private def navigate_instance_pointer(instance : JSON::Any, pointer : String) : JSON::Any?
      return instance if pointer.empty?
      tokens = Hana::Pointer.parse(pointer)

      result = instance
      tokens.each do |token|
        case result.raw
        when Array
          result = result.as_a[token.to_i]?
          return nil unless result
        when Hash
          result = result.as_h[token]?
          return nil unless result
        else
          return nil
        end
      end
      result
    end

    # Navigate a JSON::Any instance using a Location::Node path
    private def navigate_instance(instance : JSON::Any, location : Location::Node) : JSON::Any?
      navigate_instance_pointer(instance, Location.resolve(location))
    end
  end
end
