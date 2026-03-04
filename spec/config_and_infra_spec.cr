require "./spec_helper"

describe "Configuration and Infrastructure" do
  # ========================
  # Configuration Validation
  # ========================

  describe "Configuration validation" do
    describe "output_format" do
      it "rejects invalid output_format 'invalid'" do
        expect_raises(ArgumentError, /Invalid output_format/) do
          JsonSchemer::Configuration.new(output_format: "invalid")
        end
      end

      it "rejects invalid output_format 'xml'" do
        expect_raises(ArgumentError, /Invalid output_format/) do
          JsonSchemer::Configuration.new(output_format: "xml")
        end
      end

      it "rejects empty string output_format" do
        expect_raises(ArgumentError, /Invalid output_format/) do
          JsonSchemer::Configuration.new(output_format: "")
        end
      end

      it "accepts 'flag' output_format" do
        config = JsonSchemer::Configuration.new(output_format: "flag")
        config.output_format.should eq("flag")
      end

      it "accepts 'basic' output_format" do
        config = JsonSchemer::Configuration.new(output_format: "basic")
        config.output_format.should eq("basic")
      end

      it "accepts 'classic' output_format" do
        config = JsonSchemer::Configuration.new(output_format: "classic")
        config.output_format.should eq("classic")
      end

      it "accepts 'detailed' output_format" do
        config = JsonSchemer::Configuration.new(output_format: "detailed")
        config.output_format.should eq("detailed")
      end

      it "accepts 'verbose' output_format" do
        config = JsonSchemer::Configuration.new(output_format: "verbose")
        config.output_format.should eq("verbose")
      end
    end

    describe "access_mode" do
      it "rejects invalid access_mode 'invalid'" do
        expect_raises(ArgumentError, /Invalid access_mode/) do
          JsonSchemer::Configuration.new(access_mode: "invalid")
        end
      end

      it "rejects invalid access_mode 'readwrite'" do
        expect_raises(ArgumentError, /Invalid access_mode/) do
          JsonSchemer::Configuration.new(access_mode: "readwrite")
        end
      end

      it "accepts 'read' access_mode" do
        config = JsonSchemer::Configuration.new(access_mode: "read")
        config.access_mode.should eq("read")
      end

      it "accepts 'write' access_mode" do
        config = JsonSchemer::Configuration.new(access_mode: "write")
        config.access_mode.should eq("write")
      end

      it "accepts nil access_mode (default)" do
        config = JsonSchemer::Configuration.new(access_mode: nil)
        config.access_mode.should be_nil
      end
    end

    describe "max_depth" do
      it "rejects max_depth of 0" do
        expect_raises(ArgumentError, /max_depth must be > 0/) do
          JsonSchemer::Configuration.new(max_depth: 0)
        end
      end

      it "rejects negative max_depth" do
        expect_raises(ArgumentError, /max_depth must be > 0/) do
          JsonSchemer::Configuration.new(max_depth: -1)
        end
      end

      it "accepts max_depth of 1" do
        config = JsonSchemer::Configuration.new(max_depth: 1)
        config.max_depth.should eq(1)
      end

      it "accepts max_depth of 50 (default)" do
        config = JsonSchemer::Configuration.new(max_depth: 50)
        config.max_depth.should eq(50)
      end

      it "accepts max_depth of 100" do
        config = JsonSchemer::Configuration.new(max_depth: 100)
        config.max_depth.should eq(100)
      end
    end
  end

  # ========================
  # Configuration.new validation (mirrors constructor validation)
  # ========================

  describe "Configuration.new validation" do
    it "raises on invalid output_format in Configuration.new" do
      expect_raises(ArgumentError, /Invalid output_format/) do
        JsonSchemer::Configuration.new(output_format: "bad")
      end
    end

    it "raises on invalid access_mode in Configuration.new" do
      expect_raises(ArgumentError, /Invalid access_mode/) do
        JsonSchemer::Configuration.new(access_mode: "bad")
      end
    end

    it "raises on invalid max_depth in Configuration.new" do
      expect_raises(ArgumentError, /max_depth must be > 0/) do
        JsonSchemer::Configuration.new(max_depth: 0)
      end
    end
  end

  # ========================
  # Schema creation from various inputs
  # ========================

  describe "Schema creation" do
    it "creates schema from JSON string" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      schema.should be_a(JsonSchemer::Schema)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42_i64)).should be_false
    end

    it "creates schema from Hash" do
      schema = JsonSchemer.schema({"type" => JSON::Any.new("integer")} of String => JSON::Any)
      schema.should be_a(JsonSchemer::Schema)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new("hello")).should be_false
    end

    it "creates schema from parsed JSON hash" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "boolean"})).as_h)
      schema.should be_a(JsonSchemer::Schema)
      schema.valid?(JSON::Any.new(true)).should be_true
      schema.valid?(JSON::Any.new("true")).should be_false
    end

    it "raises on invalid JSON string" do
      expect_raises(JSON::ParseException) do
        JsonSchemer.schema("{invalid json}")
      end
    end
  end

  # ========================
  # Output format integration
  # ========================

  describe "Output format integration" do
    it "flag format returns only valid key" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      result = schema.validate(JSON::Any.new(42_i64), output_format: "flag")
      result["valid"].as_bool.should be_false
      result.has_key?("errors").should be_false
    end

    it "flag format returns true for valid input" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      result = schema.validate(JSON::Any.new("hello"), output_format: "flag")
      result["valid"].as_bool.should be_true
    end

    it "basic format returns errors list" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      result = schema.validate(JSON::Any.new(42_i64), output_format: "basic")
      result["valid"].as_bool.should be_false
      result.has_key?("errors").should be_true
      result["errors"].as_a.size.should be > 0
    end

    it "classic format returns detailed errors with schema pointer" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      result = schema.validate(JSON::Any.new(42_i64), output_format: "classic")
      result["valid"].as_bool.should be_false
      errors = result["errors"].as_a
      errors.size.should be > 0
      first_error = errors[0].as_h
      first_error.has_key?("error").should be_true
    end

    it "all output formats produce valid results for valid input" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      %w[flag basic classic].each do |fmt|
        result = schema.validate(JSON::Any.new("hello"), output_format: fmt)
        result["valid"].as_bool.should be_true
      end
    end

    it "all output formats produce invalid results for invalid input" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      %w[flag basic classic].each do |fmt|
        result = schema.validate(JSON::Any.new(42_i64), output_format: fmt)
        result["valid"].as_bool.should be_false
      end
    end
  end

  # ========================
  # LRU Cache
  # ========================

  describe "LRUCache" do
    it "basic get/set operations" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 3)
      cache.set("a", 1)
      cache.get("a").should eq(1)
      cache.get("b").should be_nil
    end

    it "tracks size correctly" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 5)
      cache.size.should eq(0)
      cache.set("a", 1)
      cache.size.should eq(1)
      cache.set("b", 2)
      cache.size.should eq(2)
      cache.set("a", 10) # update existing key
      cache.size.should eq(2)
    end

    it "evicts when over capacity" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 2)
      cache.set("a", 1)
      cache.set("b", 2)
      cache.size.should eq(2)

      # Adding third item should evict least recently used ("a")
      cache.set("c", 3)
      cache.size.should eq(2)
      cache.get("a").should be_nil
      cache.get("b").should eq(2)
      cache.get("c").should eq(3)
    end

    it "evicts LRU item (access order matters)" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 2)
      cache.set("a", 1)
      cache.set("b", 2)

      # Access "a" to make it more recent
      cache.get("a")

      # Adding "c" should evict "b" (now least recently used)
      cache.set("c", 3)
      cache.get("a").should eq(1)
      cache.get("b").should be_nil
      cache.get("c").should eq(3)
    end

    it "clear removes all items" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 5)
      cache.set("a", 1)
      cache.set("b", 2)
      cache.set("c", 3)
      cache.size.should eq(3)

      cache.clear
      cache.size.should eq(0)
      cache.get("a").should be_nil
      cache.get("b").should be_nil
      cache.get("c").should be_nil
    end

    it "delete removes specific item" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 5)
      cache.set("a", 1)
      cache.set("b", 2)

      deleted = cache.delete("a")
      deleted.should eq(1)
      cache.size.should eq(1)
      cache.get("a").should be_nil
      cache.get("b").should eq(2)
    end

    it "delete returns nil for missing key" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 5)
      cache.delete("missing").should be_nil
    end

    it "fetch with block computes and caches on miss" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 5)
      computed = false
      result = cache.fetch("key") do
        computed = true
        42
      end
      result.should eq(42)
      computed.should be_true

      # Second call should use cached value
      computed2 = false
      result2 = cache.fetch("key") do
        computed2 = true
        99
      end
      result2.should eq(42)
      computed2.should be_false
    end

    it "fetch tuple returns found status" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 5)

      # Miss
      found, value = cache.fetch("key")
      found.should be_false

      # Set and hit
      cache.set("key", 42)
      found, value = cache.fetch("key")
      found.should be_true
      value.should eq(42)
    end

    it "rejects max_size <= 0" do
      expect_raises(ArgumentError, /max_size must be > 0/) do
        JsonSchemer::LRUCache(String, Int32).new(max_size: 0)
      end

      expect_raises(ArgumentError, /max_size must be > 0/) do
        JsonSchemer::LRUCache(String, Int32).new(max_size: -1)
      end
    end

    it "updates value for existing key" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 3)
      cache.set("a", 1)
      cache.get("a").should eq(1)
      cache.set("a", 100)
      cache.get("a").should eq(100)
      cache.size.should eq(1)
    end

    it "max_size of 1 works correctly" do
      cache = JsonSchemer::LRUCache(String, Int32).new(max_size: 1)
      cache.set("a", 1)
      cache.get("a").should eq(1)

      cache.set("b", 2)
      cache.get("a").should be_nil
      cache.get("b").should eq(2)
      cache.size.should eq(1)
    end
  end

  # ========================
  # Error classes
  # ========================

  describe "Error classes" do
    it "UnknownRef inherits from Error" do
      err = JsonSchemer::UnknownRef.new("test")
      err.is_a?(JsonSchemer::Error).should be_true
      err.is_a?(Exception).should be_true
    end

    it "InvalidSchema inherits from Error" do
      err = JsonSchemer::InvalidSchema.new("test")
      err.is_a?(JsonSchemer::Error).should be_true
    end

    it "UnknownFormat inherits from Error" do
      err = JsonSchemer::UnknownFormat.new("test")
      err.is_a?(JsonSchemer::Error).should be_true
    end

    it "MaximumDepthExceeded inherits from Error" do
      err = JsonSchemer::MaximumDepthExceeded.new(50)
      err.is_a?(JsonSchemer::Error).should be_true
      (err.message || "").should contain("50")
    end

    it "UnknownOutputFormat inherits from Error" do
      err = JsonSchemer::UnknownOutputFormat.new("test")
      err.is_a?(JsonSchemer::Error).should be_true
    end

    it "RegexMatchLimitExceeded inherits from Error" do
      err = JsonSchemer::RegexMatchLimitExceeded.new("(a+)+$")
      err.is_a?(JsonSchemer::Error).should be_true
      (err.message || "").should contain("(a+)+$")
    end

    it "RegexFilterViolation inherits from Error" do
      err = JsonSchemer::RegexFilterViolation.new("bad.*pattern")
      err.is_a?(JsonSchemer::Error).should be_true
      (err.message || "").should contain("bad.*pattern")
    end
  end

  # ========================
  # Multiple validations with same schema (no state leakage)
  # ========================

  describe "Schema reuse (no state leakage)" do
    it "validates multiple instances without state leakage" do
      schema = JsonSchemer.schema(%q({"type": "string", "minLength": 3}))

      # Valid
      schema.valid?(JSON::Any.new("hello")).should be_true
      # Invalid (too short)
      schema.valid?(JSON::Any.new("hi")).should be_false
      # Invalid (wrong type)
      schema.valid?(JSON::Any.new(42_i64)).should be_false
      # Valid again
      schema.valid?(JSON::Any.new("world")).should be_true
    end

    it "validate method returns correct results on reuse" do
      schema = JsonSchemer.schema(%q({"type": "integer", "minimum": 0, "maximum": 100}))

      result1 = schema.validate(JSON::Any.new(50_i64))
      result1["valid"].as_bool.should be_true

      result2 = schema.validate(JSON::Any.new(-1_i64))
      result2["valid"].as_bool.should be_false

      result3 = schema.validate(JSON::Any.new(101_i64))
      result3["valid"].as_bool.should be_false

      # First valid check still works
      result4 = schema.validate(JSON::Any.new(50_i64))
      result4["valid"].as_bool.should be_true
    end
  end

  # ========================
  # Regexp resolver
  # ========================

  describe "Regexp resolver" do
    it "ruby resolver compiles valid patterns" do
      schema = JsonSchemer.schema(
        %q({"type": "string", "pattern": "^[a-z]+$"}),
        regexp_resolver: "ruby"
      )
      schema.valid?(JSON::Any.new("abc")).should be_true
      schema.valid?(JSON::Any.new("ABC")).should be_false
    end

    it "ecma resolver compiles valid patterns" do
      schema = JsonSchemer.schema(
        %q({"type": "string", "pattern": "^[a-z]+$"}),
        regexp_resolver: "ecma"
      )
      schema.valid?(JSON::Any.new("abc")).should be_true
      schema.valid?(JSON::Any.new("ABC")).should be_false
    end
  end

  # ========================
  # Global configuration isolation
  # ========================

  describe "Global configuration isolation" do
    it "per-schema format option overrides global default" do
      # Global default is format: true
      # Create schema with format: false to override
      schema_no_format = JsonSchemer.schema(%q({"format": "email"}), format: false)
      schema_with_format = JsonSchemer.schema(%q({"format": "email"}), format: true)

      schema_no_format.valid?(JSON::Any.new("not-email")).should be_true
      schema_with_format.valid?(JSON::Any.new("not-email")).should be_false
    end

    it "per-schema output_format overrides global default" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      flag_result = schema.validate(JSON::Any.new(42_i64), output_format: "flag")
      basic_result = schema.validate(JSON::Any.new(42_i64), output_format: "basic")

      flag_result.has_key?("errors").should be_false
      basic_result.has_key?("errors").should be_true
    end

    it "schemas created with explicit options are independent" do
      schema1 = JsonSchemer.schema(%q({"format": "email"}), format: true)
      schema2 = JsonSchemer.schema(%q({"format": "email"}), format: false)

      # Both should work independently
      schema1.valid?(JSON::Any.new("bad")).should be_false
      schema2.valid?(JSON::Any.new("bad")).should be_true

      # Re-check to ensure no cross-contamination
      schema1.valid?(JSON::Any.new("bad")).should be_false
      schema2.valid?(JSON::Any.new("bad")).should be_true
    end
  end

  # ========================
  # Errors.pretty helper
  # ========================

  describe "Errors.pretty" do
    it "formats required error" do
      schema = JsonSchemer.schema(%q({"type": "object", "required": ["name"]}))
      result = schema.validate(JSON.parse(%q({})))
      errors = result["errors"].as_a
      errors.size.should be > 0
      pretty = JsonSchemer::Errors.pretty(errors[0].as_h)
      pretty.should contain("missing required keys")
      pretty.should contain("name")
    end

    it "formats type error" do
      schema = JsonSchemer.schema(%q({"type": "string"}))
      result = schema.validate(JSON::Any.new(42_i64))
      errors = result["errors"].as_a
      pretty = JsonSchemer::Errors.pretty(errors[0].as_h)
      pretty.should contain("not of type")
    end
  end
end
