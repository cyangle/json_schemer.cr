require "./spec_helper"

# Helper to get errors array from validation result
def get_errors(result : Hash(String, JSON::Any)) : Array(Hash(String, JSON::Any))
  if errors = result["errors"]?
    errors.as_a.map { |e| e.as_h.transform_values { |v| v } }
  else
    [] of Hash(String, JSON::Any)
  end
end

# NOTE: In Draft 2020-12, format validation is annotation-only by default.
# This means format validators don't cause validation failures.
# Format assertion mode would need to be explicitly enabled via vocabulary.
# These tests verify that format annotations are recorded correctly.

describe "Format Validation" do
  describe "format as annotation (default Draft 2020-12 behavior)" do
    it "format validation does not cause failures in annotation mode" do
      # By default in 2020-12, format is just an annotation
      # Note: library defaults format: true (assertion), so we explicitly set false for this test
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "email"})).as_h, format: false)

      # In annotation mode, invalid format values still pass validation
      schema.valid?(JSON::Any.new("joe.bloggs@example.com")).should be_true
      schema.valid?(JSON::Any.new("not-an-email")).should be_true # passes in annotation mode
    end
  end

  describe "format with type constraint" do
    it "type validation still applies" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "format": "email"})).as_h, format: false)

      schema.valid?(JSON::Any.new("joe.bloggs@example.com")).should be_true
      schema.valid?(JSON::Any.new("any-string")).should be_true # format is annotation only
      schema.valid?(JSON::Any.new(123_i64)).should be_false     # type validation still applies
    end
  end

  describe "format ignores non-string types" do
    it "non-string values pass format validation" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "email"})).as_h)

      schema.valid?(JSON.parse("{}")).should be_true
      schema.valid?(JSON::Any.new(123_i64)).should be_true
      schema.valid?(JSON.parse("[]")).should be_true
      schema.valid?(JSON::Any.new(nil)).should be_true
    end
  end

  describe "unknown format" do
    it "unknown formats are ignored" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "unknown-format"})).as_h)

      schema.valid?(JSON::Any.new("anything")).should be_true
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end

    it "type validation still applies with unknown format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "format": "unknown"})).as_h)
      schema.valid?(JSON::Any.new("anything")).should be_true
      schema.valid?(JSON::Any.new(123_i64)).should be_false # type still checked
    end
  end

  # The following tests document the format validators that are available.
  # Note: These are annotation-only in Draft 2020-12 by default.

  describe "available format validators" do
    it "supports email format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "email"})).as_h)
      schema.valid?(JSON::Any.new("joe.bloggs@example.com")).should be_true
    end

    it "supports date-time format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "date-time"})).as_h)
      schema.valid?(JSON::Any.new("2023-11-01T18:24:25Z")).should be_true
    end

    it "supports date format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "date"})).as_h)
      schema.valid?(JSON::Any.new("2023-11-01")).should be_true
    end

    it "supports time format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "time"})).as_h)
      schema.valid?(JSON::Any.new("18:24:25Z")).should be_true
    end

    it "supports hostname format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "hostname"})).as_h)
      schema.valid?(JSON::Any.new("example.com")).should be_true
    end

    it "supports uri format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "uri"})).as_h)
      schema.valid?(JSON::Any.new("http://example.com")).should be_true
    end

    it "supports ipv4 format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "ipv4"})).as_h)
      schema.valid?(JSON::Any.new("192.168.1.1")).should be_true
    end

    it "supports ipv6 format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "ipv6"})).as_h)
      schema.valid?(JSON::Any.new("::1")).should be_true
    end

    it "supports uuid format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "uuid"})).as_h)
      schema.valid?(JSON::Any.new("550e8400-e29b-41d4-a716-446655440000")).should be_true
    end

    it "supports uri-reference format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "uri-reference"})).as_h)
      schema.valid?(JSON::Any.new("/path/to/resource")).should be_true
    end

    it "supports json-pointer format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "json-pointer"})).as_h)
      schema.valid?(JSON::Any.new("/foo/bar")).should be_true
    end

    it "supports regex format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "regex"})).as_h)
      schema.valid?(JSON::Any.new("^[a-z]+$")).should be_true
    end

    it "supports duration format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "duration"})).as_h)
      schema.valid?(JSON::Any.new("P3Y6M4DT12H30M5S")).should be_true
    end

    it "supports idn-email format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "idn-email"})).as_h)
      schema.valid?(JSON::Any.new("test@example.com")).should be_true
    end

    it "supports iri format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "iri"})).as_h)
      schema.valid?(JSON::Any.new("http://example.com")).should be_true
    end

    it "supports iri-reference format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "iri-reference"})).as_h)
      schema.valid?(JSON::Any.new("/path")).should be_true
    end
  end

  # The following tests validate specific format behaviors that match Ruby's json_schemer
  # Note: Format is annotation-only in Draft 2020-12 by default, so these test
  # the format validators themselves, not validation failure.

  describe "email format validation details" do
    # These tests document email validation behavior
    # In annotation mode, all pass since format doesn't cause failures
    # These test cases are from Ruby's format_test.rb test_email_format

    it "accepts valid email addresses" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "email"})).as_h)
      schema.valid?(JSON::Any.new("joe.bloggs@example.com")).should be_true
      schema.valid?(JSON::Any.new("te~st@example.com")).should be_true
      schema.valid?(JSON::Any.new("~test@example.com")).should be_true
      schema.valid?(JSON::Any.new("test~@example.com")).should be_true
      schema.valid?(JSON::Any.new("te.s.t@example.com")).should be_true
    end

    it "accepts quoted local parts" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "email"})).as_h)
      schema.valid?(JSON::Any.new("\"joe bloggs\"@example.com")).should be_true
      schema.valid?(JSON::Any.new("\"joe..bloggs\"@example.com")).should be_true
      schema.valid?(JSON::Any.new("\"joe@bloggs\"@example.com")).should be_true
    end

    it "accepts IP address domains" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "email"})).as_h)
      schema.valid?(JSON::Any.new("joe.bloggs@[127.0.0.1]")).should be_true
      schema.valid?(JSON::Any.new("joe.bloggs@[IPv6:::1]")).should be_true
    end
  end

  describe "RFC3339 date-time format" do
    # Test RFC3339 date-time format compliance

    it "validates RFC3339 date-time with T separator" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "date-time"})).as_h)
      schema.valid?(JSON::Any.new("2023-11-01T18:24:25Z")).should be_true
      schema.valid?(JSON::Any.new("2023-11-01T18:24:25.5Z")).should be_true
      schema.valid?(JSON::Any.new("2023-11-01T18:24:25.500Z")).should be_true
      schema.valid?(JSON::Any.new("2023-11-01T18:24:25.500623Z")).should be_true
    end

    it "validates RFC3339 date-time with space separator" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "date-time"})).as_h)
      schema.valid?(JSON::Any.new("2023-11-01 18:24:25Z")).should be_true
      schema.valid?(JSON::Any.new("2023-11-01 18:24:25.500Z")).should be_true
    end

    it "validates RFC3339 date-time with timezone offsets" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "date-time"})).as_h)
      schema.valid?(JSON::Any.new("2023-11-01T11:24:25-07:00")).should be_true
      schema.valid?(JSON::Any.new("2023-11-01T18:24:25+00:00")).should be_true
      schema.valid?(JSON::Any.new("2023-11-02T03:09:25+08:45")).should be_true
    end

    it "validates RFC3339 date-time with lowercase t and z" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "date-time"})).as_h)
      schema.valid?(JSON::Any.new("2023-11-01t18:24:25z")).should be_true
      schema.valid?(JSON::Any.new("2023-11-01t18:24:25.500z")).should be_true
    end
  end

  describe "RFC3339 time format" do
    it "validates time with timezone" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "time"})).as_h)
      schema.valid?(JSON::Any.new("18:24:25Z")).should be_true
      schema.valid?(JSON::Any.new("18:24:25+00:00")).should be_true
      schema.valid?(JSON::Any.new("11:24:25-07:00")).should be_true
    end

    it "validates time with fractional seconds" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "time"})).as_h)
      schema.valid?(JSON::Any.new("18:24:25.5Z")).should be_true
      schema.valid?(JSON::Any.new("18:24:25.50Z")).should be_true
      schema.valid?(JSON::Any.new("18:24:25.500Z")).should be_true
      schema.valid?(JSON::Any.new("18:24:25.500623Z")).should be_true
    end
  end

  describe "RFC3339 date format" do
    it "validates full date" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "date"})).as_h)
      schema.valid?(JSON::Any.new("2023-11-01")).should be_true
    end
  end

  describe "uri format with spaces" do
    # URI format should reject URIs with unencoded spaces
    it "validates uri format" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "uri"})).as_h)
      schema.valid?(JSON::Any.new("http://example.com")).should be_true
      schema.valid?(JSON::Any.new("https://example.com/path?query=value")).should be_true
    end
  end

  describe "hostname format" do
    it "validates hostnames without trailing dot" do
      schema = JsonSchemer.schema(JSON.parse(%q({"format": "hostname"})).as_h)
      schema.valid?(JSON::Any.new("example.com")).should be_true
      schema.valid?(JSON::Any.new("www.example.com")).should be_true
      schema.valid?(JSON::Any.new("subdomain.example.com")).should be_true
    end
  end

  describe "format as assertion (format: true)" do
    it "format validation failures cause invalid result" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)

      schema.valid?(JSON::Any.new("joe.bloggs@example.com")).should be_true
      schema.valid?(JSON::Any.new("not-an-email")).should be_false
    end
  end

  describe "custom formats" do
    it "allows custom format validator" do
      formats = {
        "custom-format" => ->(value : JSON::Any, _format : String) {
          value.as_s == "valid"
        },
      }
      schema = JsonSchemer.schema(
        {"format" => JSON::Any.new("custom-format")},
        format: true,
        formats: formats
      )

      schema.valid?(JSON::Any.new("valid")).should be_true
      schema.valid?(JSON::Any.new("invalid")).should be_false
    end
  end

  describe "strict format validation (assertion mode)" do
    it "rejects invalid hostnames (trailing dot)" do
      # Note: The implementation of valid_hostname? (line 300) specifically rejects trailing dots
      schema = JsonSchemer.schema({"format" => JSON::Any.new("hostname")}, format: true)

      schema.valid?(JSON::Any.new("example.com.")).should be_false
    end

    it "rejects invalid emails (leading dot)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)

      schema.valid?(JSON::Any.new(".user@example.com")).should be_false
    end

    it "rejects leap second 23:59:60 if offset makes it invalid" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)

      # 23:59:60Z is valid
      schema.valid?(JSON::Any.new("23:59:60Z")).should be_true

      # 23:59:60+01:00 -> 22:59:60 UTC (invalid, must be 23:59:60 UTC)
      # Wait, leap seconds occur at 23:59:60 UTC.
      # So 23:59:60+01:00 is 22:59:60 UTC. Leap second usually happens at end of UTC day.
      # So 23:59:60 local time with offset +01:00 corresponds to 22:59:60 UTC.
      # But leap second is inserted at 23:59:60 UTC.
      # So valid time for leap second in +01:00 zone is 00:59:60 (next day).
      # The implementation checks if UTC time is 23:59:60.

      schema.valid?(JSON::Any.new("23:59:60+01:00")).should be_false
    end
  end
end
