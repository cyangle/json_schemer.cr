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
    def insert_property_defaults(context : Schema::Context, &property_default_resolver : JSON::Any, String, Array(Tuple(Result, Bool)) -> Bool) : Bool
      inserted = false
      insert_property_defaults_recursive(context, inserted) { |v, p, r| property_default_resolver.call(v, p, r) }
    end

    def insert_property_defaults(context : Schema::Context) : Bool
      inserted = false
      insert_property_defaults_recursive(context, inserted) { |_v, _p, _r| true }
    end

    protected def insert_property_defaults_recursive(context : Schema::Context, inserted : Bool, &block : JSON::Any, String, Array(Tuple(Result, Bool)) -> Bool) : Bool
      n = nested
      return inserted unless n

      n.each do |child_result|
        if child_result.source.is_a?(Draft202012::Vocab::Applicator::Properties)
          properties_kw = child_result.source.as(Draft202012::Vocab::Applicator::Properties)
          # Navigate the internal copy (context.instance)
          copy_instance = context.original_instance(child_result.instance_location)

          if copy_instance.raw.is_a?(Hash)
            copy_hash = copy_instance.as_h

            # Also navigate the original instance (if available) for user mutation
            original_hash : Hash(String, JSON::Any)? = nil
            if orig_ref = context.original_instance_ref
              begin
                orig_node = navigate_instance(orig_ref, child_result.instance_location)
                original_hash = orig_node.as_h? if orig_node
              rescue
                # If navigation fails, skip original mutation
              end
            end

            properties_kw.schemas.each do |property, prop_schema|
              next if copy_hash.has_key?(property)
              default_kw = prop_schema.parsed["default"]?
              next unless default_kw
              next unless default_kw.is_a?(Keyword)
              default_value = default_kw.value.clone

              results = [{child_result, child_result.valid}] of Tuple(Result, Bool)
              if yield(default_value, property, results)
                copy_hash[property] = default_value
                original_hash[property] = default_value if original_hash && !original_hash.has_key?(property)
                inserted = true
              end
            end
          end
        end

        # Recurse into nested results
        inserted = child_result.insert_property_defaults_recursive(context, inserted, &block)
      end

      inserted
    end

    # Navigate a JSON::Any instance using a Location::Node path
    private def navigate_instance(instance : JSON::Any, location : Location::Node) : JSON::Any?
      path = Location.resolve(location)
      return instance if path.empty?
      tokens = Hana::Pointer.parse(path)

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
  end
end
