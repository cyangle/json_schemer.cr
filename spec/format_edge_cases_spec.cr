require "./spec_helper"

# Edge case tests for format validators
# These tests cover edge cases not already tested in format_spec.cr

describe "Format Edge Cases" do
  # ==================== DATE EDGE CASES ====================
  describe "date format edge cases" do
    # Valid date cases
    it "accepts valid leap year date (2024-02-29)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2024-02-29")).should be_true
    end

    it "accepts valid century leap year (2000-02-29)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2000-02-29")).should be_true
    end

    # Invalid date cases
    it "rejects non-leap year Feb 29 (2023-02-29)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2023-02-29")).should be_false
    end

    it "rejects month 0 (2024-00-15)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2024-00-15")).should be_false
    end

    it "rejects month 13 (2024-13-01)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2024-13-01")).should be_false
    end

    it "rejects day 0 (2024-01-00)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2024-01-00")).should be_false
    end

    it "rejects day 32 (2024-01-32)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2024-01-32")).should be_false
    end

    it "rejects April 31 (30-day month)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2024-04-31")).should be_false
    end

    it "rejects 2-digit year (24-01-15)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("24-01-15")).should be_false
    end

    it "rejects unpadded date (2024-1-1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("2024-1-1")).should be_false
    end

    it "rejects 5-digit year (12345-01-01)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("12345-01-01")).should be_false
    end

    # Valid dates at boundaries
    it "accepts minimum valid date (0001-01-01)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("0001-01-01")).should be_true
    end

    it "accepts maximum year date (9999-12-31)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("9999-12-31")).should be_true
    end

    # Non-string types pass format validation
    it "non-string types pass date format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
      schema.valid?(JSON::Any.new(nil)).should be_true
    end
  end

  # ==================== TIME EDGE CASES ====================
  describe "time format edge cases" do
    # Valid time cases
    it "accepts valid time with Z timezone" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00Z")).should be_true
    end

    it "accepts valid time with positive offset" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00+05:30")).should be_true
    end

    it "accepts valid time with negative offset" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00-08:00")).should be_true
    end

    it "accepts maximum valid time (23:59:59Z)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("23:59:59Z")).should be_true
    end

    it "accepts leap second at 23:59:60Z" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("23:59:60Z")).should be_true
    end

    it "accepts time at midnight (00:00:00Z)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("00:00:00Z")).should be_true
    end

    it "accepts time with fractional seconds" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00.123Z")).should be_true
    end

    it "accepts time with fractional seconds (6 digits)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00.123456Z")).should be_true
    end

    # Invalid time cases
    it "rejects hour 24 (24:00:00Z)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("24:00:00Z")).should be_false
    end

    it "rejects minute 60 (14:60:00Z)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:60:00Z")).should be_false
    end

    it "rejects second 61 without leap (14:30:61Z)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:61Z")).should be_false
    end

    it "rejects time without timezone" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00")).should be_false
    end

    it "rejects time with invalid offset hour (14:30:00+24:00)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00+24:00")).should be_false
    end

    it "rejects time with invalid offset minute (14:30:00+05:60)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00+05:60")).should be_false
    end

    it "rejects time with uppercase T separator" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("14:30:00T05:30")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass time format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("time")}, format: true)
      schema.valid?(JSON::Any.new("not-time")).should be_false
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== DURATION EDGE CASES ====================
  describe "duration format edge cases" do
    # Valid duration cases
    it "accepts duration with years (P1Y)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P1Y")).should be_true
    end

    it "accepts duration with months (P1M)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P1M")).should be_true
    end

    it "accepts duration with weeks (P1W)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P1W")).should be_true
    end

    it "accepts duration with days (P1D)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P1D")).should be_true
    end

    it "accepts duration with hours (PT1H)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("PT1H")).should be_true
    end

    it "accepts duration with minutes (PT1M)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("PT1M")).should be_true
    end

    it "accepts duration with seconds (PT1S)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("PT1S")).should be_true
    end

    it "accepts complex duration (P1Y2M3DT4H5M6S)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P1Y2M3DT4H5M6S")).should be_true
    end

    it "accepts duration with fractional seconds (PT0.5S)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("PT0.5S")).should be_true
    end

    it "accepts zero duration (P0D)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P0D")).should be_true
    end

    it "accepts only T with time components (PT1H)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("PT1H")).should be_true
    end

    # Invalid duration cases
    it "rejects empty string" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("")).should be_false
    end

    it "rejects P with no components" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P")).should be_false
    end

    it "rejects T with no time components" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("PT")).should be_false
    end

    it "rejects duration without P prefix (1Y)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("1Y")).should be_false
    end

    it "rejects weeks mixed with other date units (P1Y2W)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P1Y2W")).should be_false
    end

    it "rejects weeks mixed with days (P1W1D)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P1W1D")).should be_false
    end

    it "rejects duration with whitespace" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new("P 1Y")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass duration format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("duration")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== EMAIL EDGE CASES ====================
  describe "email format edge cases" do
    # Valid email cases
    it "accepts basic email (user@example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user@example.com")).should be_true
    end

    it "accepts email with plus tag (user+tag@example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user+tag@example.com")).should be_true
    end

    it "accepts email with subdomain (user@sub.domain.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user@sub.domain.com")).should be_true
    end

    it "accepts email with hyphen in domain" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user@my-domain.com")).should be_true
    end

    it "accepts email with apostrophe in local part (o'brien@example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("o'brien@example.com")).should be_true
    end

    # Invalid email cases
    it "rejects email with no local part (@example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("@example.com")).should be_false
    end

    it "rejects email with no domain (user@)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user@")).should be_false
    end

    it "rejects email with double @ (user@@domain.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user@@domain.com")).should be_false
    end

    it "rejects empty string" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("")).should be_false
    end

    it "rejects email with space (user @example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user @example.com")).should be_false
    end

    it "rejects email with leading dot (.user@example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new(".user@example.com")).should be_false
    end

    it "rejects email with trailing dot in local (user.@example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user.@example.com")).should be_false
    end

    it "rejects email with consecutive dots (user..name@example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("user..name@example.com")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass email format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== IPV4 EDGE CASES ====================
  describe "ipv4 format edge cases" do
    # Valid IPv4 cases
    it "accepts standard IPv4 (192.168.1.1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("192.168.1.1")).should be_true
    end

    it "accepts IPv4 all zeros (0.0.0.0)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("0.0.0.0")).should be_true
    end

    it "accepts IPv4 all ones (1.1.1.1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("1.1.1.1")).should be_true
    end

    it "accepts IPv4 all 255s (255.255.255.255)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("255.255.255.255")).should be_true
    end

    it "accepts IPv4 with single digit octets (1.2.3.4)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("1.2.3.4")).should be_true
    end

    # Invalid IPv4 cases
    it "rejects IPv4 octet > 255 (256.1.1.1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("256.1.1.1")).should be_false
    end

    it "rejects IPv4 with only 3 octets (1.2.3)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("1.2.3")).should be_false
    end

    it "rejects IPv4 with 5 octets (1.2.3.4.5)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("1.2.3.4.5")).should be_false
    end

    it "rejects IPv4 with leading zeros (01.02.03.04)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("01.02.03.04")).should be_false
    end

    it "rejects IPv4 with letters (192.168.1.a)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("192.168.1.a")).should be_false
    end

    it "rejects IPv4 with empty octet (.1.2.3)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new(".1.2.3")).should be_false
    end

    it "rejects IPv4 with consecutive dots (1..2.3.4)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("1..2.3.4")).should be_false
    end

    it "rejects IPv4 with negative number (-1.2.3.4)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new("-1.2.3.4")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass ipv4 format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv4")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== IPV6 EDGE CASES ====================
  describe "ipv6 format edge cases" do
    # Valid IPv6 cases
    it "accepts loopback address (::1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("::1")).should be_true
    end

    it "accepts full IPv6 address (2001:0db8:0000:0000:0000:ff00:0042:8329)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("2001:0db8:0000:0000:0000:ff00:0042:8329")).should be_true
    end

    it "accepts compressed IPv6 (2001:db8::1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("2001:db8::1")).should be_true
    end

    it "accepts IPv6 all zeros (::)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("::")).should be_true
    end

    it "accepts IPv6 with uppercase letters (2001:DB8::1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("2001:DB8::1")).should be_true
    end

    it "accepts IPv4-mapped IPv6 (::ffff:192.168.1.1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("::ffff:192.168.1.1")).should be_true
    end

    # Invalid IPv6 cases
    it "rejects IPv6 with invalid hex (::gggg)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("::gggg")).should be_false
    end

    it "rejects IPv6 segment > 4 hex chars (12345::1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("12345::1")).should be_false
    end

    it "rejects IPv6 with 9 colons (1:2:3:4:5:6:7:8:9)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("1:2:3:4:5:6:7:8:9")).should be_false
    end

    it "rejects IPv6 with double compression (::1::)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("::1::")).should be_false
    end

    it "rejects IPv6 with empty segment (1:::1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new("1:::1")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass ipv6 format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("ipv6")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== URI EDGE CASES ====================
  describe "uri format edge cases" do
    # Valid URI cases
    it "accepts basic HTTP URI" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com")).should be_true
    end

    it "accepts HTTPS URI" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("https://example.com")).should be_true
    end

    it "accepts URI with path (https://example.com/path)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("https://example.com/path")).should be_true
    end

    it "accepts URI with query (https://example.com/path?q=1)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("https://example.com/path?q=1")).should be_true
    end

    it "accepts URI with fragment (https://example.com/path?q=1#frag)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("https://example.com/path?q=1#frag")).should be_true
    end

    it "accepts URN (urn:isbn:0451450523)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("urn:isbn:0451450523")).should be_true
    end

    it "accepts URI with port (http://example.com:8080)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com:8080")).should be_true
    end

    it "accepts URI with user info (http://user:pass@example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("http://user:pass@example.com")).should be_true
    end

    # Invalid URI cases
    it "rejects URI without scheme (example.com)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("example.com")).should be_false
    end

    it "rejects URI with no scheme (://missing-scheme)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("://missing-scheme")).should be_false
    end

    it "rejects empty string" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("")).should be_false
    end

    it "rejects URI with unencoded space (http://example.com/path with space)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/path with space")).should be_false
    end

    it "rejects URI with control character" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/path\x00")).should be_false
    end

    it "rejects not a URI string" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("not a uri")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass uri format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== UUID EDGE CASES ====================
  describe "uuid format edge cases" do
    # Valid UUID cases
    it "accepts standard UUID (f47ac10b-58cc-4372-a567-0e02b2c3d479)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("f47ac10b-58cc-4372-a567-0e02b2c3d479")).should be_true
    end

    it "accepts nil UUID (00000000-0000-0000-0000-000000000000)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("00000000-0000-0000-0000-000000000000")).should be_true
    end

    it "accepts UUID with uppercase (F47AC10B-58CC-4372-A567-0E02B2C3D479)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("F47AC10B-58CC-4372-A567-0E02B2C3D479")).should be_true
    end

    it "accepts UUID with mixed case (F47aC10b-58cC-4372-a567-0e02b2c3d479)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("F47aC10b-58cC-4372-a567-0e02b2c3d479")).should be_true
    end

    # Invalid UUID cases
    it "rejects not a UUID string" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("not-a-uuid")).should be_false
    end

    it "rejects truncated UUID (f47ac10b-58cc-4372-a567)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("f47ac10b-58cc-4372-a567")).should be_false
    end

    it "rejects UUID without hyphens (f47ac10b58cc4372a5670e02b2c3d479)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("f47ac10b58cc4372a5670e02b2c3d479")).should be_false
    end

    it "rejects UUID with lowercase x (f47ac10b-58cc-4372-a567-0e02b2c3d47x)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("f47ac10b-58cc-4372-a567-0e02b2c3d47x")).should be_false
    end

    it "rejects UUID with wrong length (f47ac10b-58cc-4372-a567-0e02b2c3d47)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("f47ac10b-58cc-4372-a567-0e02b2c3d47")).should be_false
    end

    it "rejects UUID with extra hyphens (f47ac10b-58cc-4372-a567-0e02-b2c3d479)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("f47ac10b-58cc-4372-a567-0e02-b2c3d479")).should be_false
    end

    it "rejects empty string" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new("")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass uuid format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uuid")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== JSON-POINTER EDGE CASES ====================
  describe "json-pointer format edge cases" do
    # Valid JSON Pointer cases
    it "accepts root pointer (empty string)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("")).should be_true
    end

    it "accepts simple pointer (/foo)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/foo")).should be_true
    end

    it "accepts nested pointer (/foo/0)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/foo/0")).should be_true
    end

    it "accepts pointer with escaped tilde (/a~0b)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/a~0b")).should be_true
    end

    it "accepts pointer with escaped slash (/a~1b)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/a~1b")).should be_true
    end

    it "accepts pointer with multiple segments (/a/b/c)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/a/b/c")).should be_true
    end

    it "accepts pointer with ~0 followed by ~1 (/a~0b~1c)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/a~0b~1c")).should be_true
    end

    # Invalid JSON Pointer cases
    it "rejects pointer without leading slash (foo)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("foo")).should be_false
    end

    it "rejects pointer with invalid escape (/~2)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/~2")).should be_false
    end

    it "accepts pointer with trailing slash (/foo/) as valid empty segment" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/foo/")).should be_true
    end

    it "accepts pointer with consecutive slashes (/foo//bar) as valid empty segment" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/foo//bar")).should be_true
    end

    it "rejects pointer with single ~ (/~)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/~")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass json-pointer format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("json-pointer")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== RELATIVE-JSON-POINTER EDGE CASES ====================
  describe "relative-json-pointer format edge cases" do
    # Valid Relative JSON Pointer cases
    it "accepts zero offset (0)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("0")).should be_true
    end

    it "accepts index with member (1/foo)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("1/foo")).should be_true
    end

    it "accepts zero with hash (0#)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("0#")).should be_true
    end

    it "accepts index with nested member (2/foo/bar)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("2/foo/bar")).should be_true
    end

    it "accepts large index (123/foo)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("123/foo")).should be_true
    end

    it "rejects zero with hash and extra text (0#foo) since # must be terminal" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("0#foo")).should be_false
    end

    it "accepts just hash (1#)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("1#")).should be_true
    end

    # Invalid Relative JSON Pointer cases
    it "rejects hash without index (#)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("#")).should be_false
    end

    it "rejects JSON pointer style (/foo)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("/foo")).should be_false
    end

    it "rejects index starting with 0 followed by digit (01/foo)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("01/foo")).should be_false
    end

    it "rejects negative index (-1/foo)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("-1/foo")).should be_false
    end

    it "rejects empty string" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("")).should be_false
    end

    it "rejects non-numeric index (a/foo)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new("a/foo")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass relative-json-pointer format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("relative-json-pointer")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ==================== URI-TEMPLATE EDGE CASES ====================
  describe "uri-template format edge cases" do
    # Valid URI Template cases
    it "accepts URI template with variable (http://example.com/{id})" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/{id}")).should be_true
    end

    it "accepts URI template with path expansion ({+path}/here)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("{+path}/here")).should be_true
    end

    it "accepts URI template with fragment expansion ({#fragment})" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/{#fragment}")).should be_true
    end

    it "accepts URI template with multiple variables (http://example.com/{lat},{long})" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/{lat},{long}")).should be_true
    end

    it "accepts simple URI (http://example.com/)" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/")).should be_true
    end

    # Invalid URI Template cases
    it "rejects URI template with unclosed brace" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/{")).should be_false
    end

    it "rejects URI template with unmatched close brace (http://example.com/})" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/}")).should be_false
    end

    it "rejects URI template with nested braces (http://example.com/{outer{inner}})" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/{outer{inner}}")).should be_false
    end

    it "rejects URI template with empty braces (http://example.com/{})" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new("http://example.com/{}")).should be_false
    end

    # Non-string types pass format validation
    it "non-string types pass uri-template format validation" do
      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri-template")}, format: true)
      schema.valid?(JSON::Any.new(123_i64)).should be_true
    end
  end

  # ====================FORMAT AS ASSERTION MODE ====================
  describe "format assertion mode edge cases" do
    it "all format validators work in assertion mode" do
      # Test all formats in assertion mode (format: true)
      formats = %w[date time duration email ipv4 ipv6 uri uuid json-pointer relative-json-pointer uri-template]

      formats.each do |fmt|
        schema = JsonSchemer.schema({"format" => JSON::Any.new(fmt)}, format: true)
        # Valid instances should pass
        case fmt
        when "date"
          schema.valid?(JSON::Any.new("2024-01-15")).should be_true
        when "time"
          schema.valid?(JSON::Any.new("14:30:00Z")).should be_true
        when "duration"
          schema.valid?(JSON::Any.new("P1D")).should be_true
        when "email"
          schema.valid?(JSON::Any.new("test@example.com")).should be_true
        when "ipv4"
          schema.valid?(JSON::Any.new("192.168.1.1")).should be_true
        when "ipv6"
          schema.valid?(JSON::Any.new("::1")).should be_true
        when "uri"
          schema.valid?(JSON::Any.new("http://example.com")).should be_true
        when "uuid"
          schema.valid?(JSON::Any.new("00000000-0000-0000-0000-000000000000")).should be_true
        when "json-pointer"
          schema.valid?(JSON::Any.new("/foo")).should be_true
        when "relative-json-pointer"
          schema.valid?(JSON::Any.new("0")).should be_true
        when "uri-template"
          schema.valid?(JSON::Any.new("http://example.com/{id}")).should be_true
        end
      end
    end

    it "all invalid format values fail in assertion mode" do
      # Test all formats with invalid values in assertion mode
      schema = JsonSchemer.schema({"format" => JSON::Any.new("email")}, format: true)
      schema.valid?(JSON::Any.new("not-an-email")).should be_false

      schema = JsonSchemer.schema({"format" => JSON::Any.new("date")}, format: true)
      schema.valid?(JSON::Any.new("invalid-date")).should be_false

      schema = JsonSchemer.schema({"format" => JSON::Any.new("uri")}, format: true)
      schema.valid?(JSON::Any.new("not-a-uri")).should be_false
    end
  end
end
