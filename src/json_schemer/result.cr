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

    # Alias for compatibility - note: can't use "annotation" as method name, it's reserved in Crystal
    def get_annotation : JSON::Any?
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
        source.error(formatted_instance_location: formatted_instance_location, details: details)
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
        out["annotation"] = result_annotation.not_nil! if result_annotation
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
      out["details"] = JSON::Any.new(details.not_nil!.transform_values { |v| v }) if details
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
        if n.any?
          errors = [] of Hash(String, JSON::Any)
          collect_basic_errors(errors)
          out[nested_key] = JSON::Any.new(errors.map { |e| JSON::Any.new(e.transform_values { |v| v }) })
        end
      end
      out
    end

    protected def collect_basic_errors(errors : Array(Hash(String, JSON::Any)))
      if ignore_nested || nested.nil? || nested.not_nil!.empty?
        errors << to_output_unit
      else
        nested.not_nil!.each do |result|
          if result.valid == valid
            result.collect_basic_errors(errors)
          end
        end
      end
    end

    # Detailed output format
    def detailed : Hash(String, JSON::Any)
      return to_output_unit if ignore_nested || nested.nil? || nested.not_nil!.empty?

      matching = nested.not_nil!.select { |r| r.valid == valid }
      if matching.size == 1
        matching.first.detailed
      else
        out = to_output_unit
        if matching.any?
          out[nested_key] = JSON::Any.new(matching.map { |r| JSON::Any.new(r.detailed.transform_values { |v| v }) })
        end
        out
      end
    end

    # Verbose output format
    def verbose : Hash(String, JSON::Any)
      out = to_output_unit
      if n = nested
        if n.any?
          out[nested_key] = JSON::Any.new(n.map { |r| JSON::Any.new(r.verbose.transform_values { |v| v }) })
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
        if ignore_nested || nested.nil? || nested.not_nil!.empty?
          errors << to_classic
        else
          added = false
          nested.not_nil!.each do |result|
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
      if result.ignore_nested || result.nested.nil? || result.nested.not_nil!.empty?
        yield result.to_classic
      else
        added = false
        result.nested.not_nil!.each do |nested_result|
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
  end
end
