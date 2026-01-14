require "uri/punycode"
require "simpleidn"

# require "icu" # Removed direct require since simpleidn handles it

module JsonSchemer
  # Format validation module
  module Format
    # Regex patterns
    DATE_TIME_OFFSET_REGEX      = /(Z|[\+\-]([01][0-9]|2[0-3]):[0-5][0-9])\z/i
    DATE_TIME_SEPARATOR_CLASS   = "[Tt\\s]"
    HOUR_24_REGEX               = /#{DATE_TIME_SEPARATOR_CLASS}24:/
    LEAP_SECOND_REGEX           = /#{DATE_TIME_SEPARATOR_CLASS}\d{2}:\d{2}:6/
    IP_REGEX                    = /\A[0-9a-fA-F:.]+\z/
    INVALID_QUERY_REGEX         = /\s/
    IRI_ESCAPE_REGEX            = /[^\x00-\x7F]/
    UUID_REGEX                  = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/
    NIL_UUID                    = "00000000-0000-0000-0000-000000000000"
    JSON_POINTER_REGEX          = /\A(\/([^~\/]|~[01])*)*\z/
    RELATIVE_JSON_POINTER_REGEX = /\A(0|[1-9]\d*)(#|(\/([^~\/]|~[01])*)*)\z/
    DURATION_REGEX              = /\AP(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+(\.\d+)?S)?)?\z/
    HOSTNAME_REGEX              = /\A([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\z/
    EMAIL_REGEX                 = /\A[^\s@]+@[^\s@]+\z/
    URI_TEMPLATE_REGEX          = /\A([^\{\}]|\{[^\{\}]+\})*\z/

    # RFC 3339 date format: YYYY-MM-DD (exactly 4-digit year, 2-digit month, 2-digit day)
    DATE_REGEX = /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/
    # RFC 3339 time format: HH:MM:SS or HH:MM:SS.fraction with timezone (strict offset validation)
    TIME_REGEX = /\A[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[\+\-]([01][0-9]|2[0-3]):[0-5][0-9])\z/i
    # RFC 3339 date-time format with stricter timezone offset validation
    # Offset hours: 00-23, minutes: 00-59
    DATE_TIME_REGEX = /\A[0-9]{4}-[0-9]{2}-[0-9]{2}[Tt\s][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[\+\-]([01][0-9]|2[0-3]):[0-5][0-9])\z/i

    FRAGMENT_ENCODE_REGEX = /[^\w?\/:@\-.~!$&'()*+,;=]/

    # Format validator type
    alias FormatValidator = Proc(JSON::Any, String, Bool)

    # Percent encode helper
    def self.percent_encode(data : String, regexp : Regex) : String
      data.gsub(regexp) do |match|
        match.bytes.map { |b| "%%%02X" % b }.join
      end
    end

    # Date-time validation (RFC 3339)
    def self.valid_date_time?(data : String) : Bool
      # Must match RFC 3339 format: YYYY-MM-DDTHH:MM:SS(.fraction)?(Z|+/-HH:MM)
      return false unless DATE_TIME_REGEX.matches?(data)

      # Check for hour 24 which is not valid in RFC 3339
      return false if data.includes?("T24:") || data.includes?("t24:")

      # Extract date and time parts
      date_part = data[0, 10]
      time_part_match = data.match(/[Tt\s](\d{2}):(\d{2}):(\d{2})/)
      return false unless time_part_match

      hour = time_part_match[1].to_i
      minute = time_part_match[2].to_i
      second = time_part_match[3].to_i

      # Validate date part
      return false unless valid_date?(date_part)

      # Validate time ranges
      return false if hour > 23
      return false if minute > 59

      # Handle leap seconds (second = 60)
      if second == 60
        # Leap seconds are only valid at 23:59 UTC
        # For local times with offset, check that when converted to UTC it would be 23:59
        # For simplicity, we check that the local time is at hour 23 or with appropriate offset
        # RFC 3339 says leap second is valid at 23:59:60Z or at equivalent local time
        # We'll accept leap seconds at any hour 23 with minute 59, or at end of day with offset
        # A stricter check: leap second must be at HH:59:60 where HH + offset = 23 UTC
        # For simplicity in this implementation, we require minute == 59 and validate hour logic

        # Extract offset to determine if this could be a valid leap second
        if data.includes?("Z") || data.includes?("z")
          # UTC time: must be 23:59:60
          return false unless hour == 23 && minute == 59
        else
          # With offset, the local time must be such that UTC is 23:59
          offset_match = data.match(/([\+\-])(\d{2}):(\d{2})\z/)
          if offset_match
            offset_sign = offset_match[1] == "+" ? 1 : -1
            offset_hours = offset_match[2].to_i
            offset_minutes = offset_match[3].to_i

            # Calculate what UTC hour would be
            # Local time - offset = UTC time
            # So for +08:00, local 07:59:60 = UTC 23:59:60 (valid)
            # For -08:00, local 31:59:60 would be needed which is impossible, so local 15:59:60 = UTC 23:59:60 (valid)
            utc_hour = hour - (offset_sign * offset_hours)
            utc_hour = (utc_hour + 24) % 24 if utc_hour < 0
            utc_hour = utc_hour % 24 if utc_hour >= 24

            return false unless utc_hour == 23 && minute == 59
          else
            return false
          end
        end
      elsif second > 59
        return false
      end

      true
    end

    # Date validation (RFC 3339 full-date)
    def self.valid_date?(data : String) : Bool
      # Must match RFC 3339 date format exactly: YYYY-MM-DD
      return false unless DATE_REGEX.matches?(data)

      # Also validate it's a real date by parsing
      begin
        year = data[0, 4].to_i
        month = data[5, 2].to_i
        day = data[8, 2].to_i

        return false if month < 1 || month > 12

        # Days per month (handle leap years)
        days_in_month = case month
                        when 1, 3, 5, 7, 8, 10, 12 then 31
                        when 4, 6, 9, 11           then 30
                        when 2
                          leap_year?(year) ? 29 : 28
                        else
                          return false
                        end

        day >= 1 && day <= days_in_month
      rescue
        false
      end
    end

    # Check if year is a leap year
    private def self.leap_year?(year : Int32) : Bool
      (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    end

    # Time validation (RFC 3339 full-time)
    def self.valid_time?(data : String) : Bool
      # Must match RFC 3339 time format
      return false unless TIME_REGEX.matches?(data)

      # Extract time parts
      time_match = data.match(/(\d{2}):(\d{2}):(\d{2})/)
      return false unless time_match

      hour = time_match[1].to_i
      minute = time_match[2].to_i
      second = time_match[3].to_i

      # Validate ranges
      return false if hour > 23
      return false if minute > 59

      # Handle leap seconds (second = 60)
      if second == 60
        # Leap seconds are valid at the end of UTC day (23:59:60Z)
        # For times with offset, check if it would be 23:59 UTC
        if data.includes?("Z") || data.includes?("z")
          return false unless hour == 23 && minute == 59
        else
          offset_match = data.match(/([\+\-])(\d{2}):(\d{2})\z/)
          if offset_match
            offset_sign = offset_match[1] == "+" ? 1 : -1
            offset_hours = offset_match[2].to_i
            offset_minutes = offset_match[3].to_i

            # Convert to total minutes for easier calculation
            local_total_minutes = hour * 60 + minute
            offset_total_minutes = offset_sign * (offset_hours * 60 + offset_minutes)

            # UTC = local - offset
            utc_total_minutes = local_total_minutes - offset_total_minutes

            # Normalize to 0-1439 (minutes in a day)
            utc_total_minutes = (utc_total_minutes + 1440) % 1440 if utc_total_minutes < 0
            utc_total_minutes = utc_total_minutes % 1440 if utc_total_minutes >= 1440

            utc_hour = utc_total_minutes // 60
            utc_minute = utc_total_minutes % 60

            return false unless utc_hour == 23 && utc_minute == 59
          else
            return false
          end
        end
      elsif second > 59
        return false
      end

      true
    end

    # Duration validation (ISO 8601)
    def self.valid_duration?(data : String) : Bool
      # Must only use ASCII digits
      return false unless data.ascii_only?

      return false unless DURATION_REGEX.matches?(data)

      # Ensure at least one component is present after P
      return false if data.size <= 1

      # Check that there's at least one duration component
      has_component = data.match(/[0-9]+[YMWDHS]/i)
      return false unless has_component

      # Weeks cannot be combined with other date/time units (ISO 8601 restriction)
      if data.includes?("W")
        # W can only appear alone with P, like P2W or P1W
        # Invalid: P1Y2W, P1W1D, etc.
        # Valid patterns with W: P<digits>W only
        return false unless data.matches?(/\AP[0-9]+W\z/)
      end

      # If there's a T, make sure there's content after it
      if data.includes?("T")
        time_part = data.split("T").last
        return false if time_part.empty?
      end

      true
    end

    # IP address validation
    def self.valid_ip?(data : String, family : Socket::Family) : Bool
      begin
        addr = Socket::IPAddress.new(data, 0)
        case family
        when Socket::Family::INET
          addr.family == Socket::Family::INET
        when Socket::Family::INET6
          addr.family == Socket::Family::INET6
        else
          false
        end
      rescue
        false
      end
    end

    # Characters disallowed in URIs per RFC 3986
    # These must be percent-encoded (note: [] allowed in host for IPv6)
    URI_DISALLOWED_CHARS = /[\x00-\x20\x7F<>"{}|\\^`]/
    # Brackets are only allowed in the host portion for IPv6
    URI_BRACKET_IN_USERINFO = /\/\/[^\/@]*[\[\]][^\/@]*@/

    # URI validation
    def self.valid_uri?(data : String) : Bool
      return false unless data.ascii_only?
      return false if URI_DISALLOWED_CHARS.matches?(data)
      return false if URI_BRACKET_IN_USERINFO.matches?(data)
      begin
        uri = URI.parse(data)
        return false if INVALID_QUERY_REGEX.matches?(uri.query || "")
        !uri.scheme.nil? && !uri.scheme.not_nil!.empty?
      rescue
        false
      end
    end

    # URI reference validation
    def self.valid_uri_reference?(data : String) : Bool
      return false unless data.ascii_only?
      return false if URI_DISALLOWED_CHARS.matches?(data)
      return false if URI_BRACKET_IN_USERINFO.matches?(data)
      begin
        uri = URI.parse(data)
        return false if INVALID_QUERY_REGEX.matches?(uri.query || "")
        true
      rescue
        false
      end
    end

    # IRI escape
    def self.iri_escape(data : String) : String
      percent_encode(data, IRI_ESCAPE_REGEX)
    end

    # JSON pointer validation
    def self.valid_json_pointer?(data : String) : Bool
      JSON_POINTER_REGEX.matches?(data)
    end

    # Relative JSON pointer validation
    def self.valid_relative_json_pointer?(data : String) : Bool
      RELATIVE_JSON_POINTER_REGEX.matches?(data)
    end

    # Hostname validation (RFC 1123, RFC 5890)
    def self.valid_hostname?(data : String) : Bool
      return false if data.empty?
      return false if data.size > 253

      # Cannot start or end with dot
      return false if data.starts_with?('.') || data.ends_with?('.')

      # Split into labels
      labels = data.split('.')
      return false if labels.empty?

      labels.each do |label|
        return false if label.empty?
        return false if label.size > 63

        # Cannot start or end with hyphen
        return false if label.starts_with?('-') || label.ends_with?('-')

        # Cannot contain underscore
        return false if label.includes?('_')

        # Check for xn-- prefix (Punycode/A-label)
        if label.downcase.starts_with?("xn--")
          # Validate A-label using IDNA2008 (via SimpleIDN)
          # Punycode itself is just an encoding, but "hostname" format implies valid IDN
          return false unless SimpleIDN.to_ascii_2008(label)

          punycode_part = label[4..]
          return false if punycode_part.empty?
          begin
            decoded = URI::Punycode.decode(punycode_part)
            # Labels cannot have -- in positions 3-4 unless they're xn-- labels (which are A-labels)
            # But the *decoded* U-label MUST NOT contain -- in 3rd and 4th position (RFC 5890)
            return false if decoded.size >= 4 && decoded[2] == '-' && decoded[3] == '-'
          rescue
            return false
          end
        elsif label.size >= 4 && label[2..3] == "--"
          # Labels cannot have -- in positions 3-4 unless they're xn-- labels
          return false
        end

        # Each character must be alphanumeric or hyphen
        label.each_char do |c|
          unless c.ascii_letter? || c.ascii_number? || c == '-'
            return false
          end
        end
      end

      true
    end

    # IDN Hostname validation
    def self.valid_idn_hostname?(data : String) : Bool
      return false if data.empty?

      # Use SimpleIDN with ICU support (to_ascii_2008)
      # This performs full IDNA2008 validation including Bidi rules, ContextJ, etc.
      ascii_domain = SimpleIDN.to_ascii_2008(data)
      return false if ascii_domain.nil?

      valid_hostname?(ascii_domain)
    end

    # Email validation (RFC 5321/5322 compliant)
    def self.valid_email?(data : String) : Bool
      return false unless data.ascii_only?

      # Handle quoted local part specially - find the @ that's not in quotes
      local_part : String
      domain_part : String

      if data.starts_with?('"')
        # Quoted local part - find closing quote then @
        closing_quote = data.index('"', 1)
        return false unless closing_quote
        return false unless closing_quote + 1 < data.size && data[closing_quote + 1] == '@'

        local_part = data[0..closing_quote]
        domain_part = data[(closing_quote + 2)..]
      else
        # Unquoted - simple split
        at_index = data.index('@')
        return false unless at_index

        local_part = data[0...at_index]
        domain_part = data[(at_index + 1)..]
      end

      return false if local_part.empty? || domain_part.empty?

      # Validate local part
      if local_part.starts_with?('"') && local_part.ends_with?('"')
        # Quoted string - allow most characters including spaces and @
        return false if local_part.size < 2
        # Content between quotes should not have unescaped quotes
        inner = local_part[1...-1]
        # Simple validation: no null chars, backslash escapes are valid
        return false if inner.includes?('\0')
      else
        # Unquoted local part
        # Cannot start or end with a dot
        return false if local_part.starts_with?('.') || local_part.ends_with?('.')
        # Cannot have consecutive dots
        return false if local_part.includes?("..")
        # Must only contain valid characters
        return false unless local_part.matches?(/\A[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+\z/)
      end

      # Validate domain part
      if domain_part.starts_with?('[') && domain_part.ends_with?(']')
        # IP address literal
        ip_literal = domain_part[1...-1]
        if ip_literal.starts_with?("IPv6:")
          # IPv6 address
          return valid_ip?(ip_literal[5..], Socket::Family::INET6)
        else
          # IPv4 address
          return valid_ip?(ip_literal, Socket::Family::INET)
        end
      else
        # Domain name - must not contain = or other invalid chars
        return false if domain_part.includes?('=')
        return valid_hostname?(domain_part)
      end

      true
    end

    # IDN Email validation (internationalized domain names)
    def self.valid_idn_email?(data : String) : Bool
      # Find the @ separator (not in a quoted local part)
      local_part : String
      domain_part : String

      if data.starts_with?('"')
        # Quoted local part - find closing quote then @
        closing_quote = data.index('"', 1)
        return false unless closing_quote
        return false unless closing_quote + 1 < data.size && data[closing_quote + 1] == '@'

        local_part = data[0..closing_quote]
        domain_part = data[(closing_quote + 2)..]
      else
        # Unquoted - simple split at first @
        at_index = data.index('@')
        return false unless at_index

        local_part = data[0...at_index]
        domain_part = data[(at_index + 1)..]
      end

      return false if local_part.empty? || domain_part.empty?

      # Validate local part - for IDN emails, allow Unicode letters in unquoted part
      if local_part.starts_with?('"') && local_part.ends_with?('"')
        return false if local_part.size < 2
        inner = local_part[1...-1]
        return false if inner.includes?('\0')
      else
        return false if local_part.starts_with?('.') || local_part.ends_with?('.')
        return false if local_part.includes?("..")
        # Allow Unicode letters and common email special chars
        local_part.each_char do |c|
          unless c.letter? || c.ascii_number? || ".!#$%&'*+/=?^_`{|}~-".includes?(c)
            return false
          end
        end
      end

      # Validate domain part - allow Unicode characters (IDN)
      if domain_part.starts_with?('[') && domain_part.ends_with?(']')
        ip_literal = domain_part[1...-1]
        if ip_literal.starts_with?("IPv6:")
          return valid_ip?(ip_literal[5..], Socket::Family::INET6)
        else
          return valid_ip?(ip_literal, Socket::Family::INET)
        end
      else
        # For IDN hostnames, allow Unicode letters
        return valid_idn_hostname?(domain_part)
      end

      true
    end

    # UUID validation
    def self.valid_uuid?(data : String) : Bool
      UUID_REGEX.matches?(data) || data == NIL_UUID
    end

    # URI template validation
    def self.valid_uri_template?(data : String) : Bool
      URI_TEMPLATE_REGEX.matches?(data)
    end

    # Regex validation
    def self.valid_regex?(data : String) : Bool
      EcmaRegexp.valid?(data)
    end

    # Format validators as procs
    DATE_TIME = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_date_time?(instance.as_s)
    }

    DATE = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_date?(instance.as_s)
    }

    TIME = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_time?(instance.as_s)
    }

    DURATION = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_duration?(instance.as_s)
    }

    EMAIL = ->(instance : JSON::Any, _format : String) {
      s = instance.as_s?
      !s || (s.ascii_only? && valid_email?(s))
    }

    IDN_EMAIL = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_idn_email?(instance.as_s)
    }

    HOSTNAME = ->(instance : JSON::Any, _format : String) {
      s = instance.as_s?
      !s || (s.ascii_only? && valid_hostname?(s))
    }

    IDN_HOSTNAME = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_idn_hostname?(instance.as_s)
    }

    IPV4 = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_ip?(instance.as_s, Socket::Family::INET)
    }

    IPV6 = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_ip?(instance.as_s, Socket::Family::INET6)
    }

    URI_FORMAT = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_uri?(instance.as_s)
    }

    URI_REFERENCE = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_uri_reference?(instance.as_s)
    }

    IRI = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_uri?(iri_escape(instance.as_s))
    }

    IRI_REFERENCE = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_uri_reference?(iri_escape(instance.as_s))
    }

    JSON_POINTER = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_json_pointer?(instance.as_s)
    }

    RELATIVE_JSON_POINTER = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_relative_json_pointer?(instance.as_s)
    }

    UUID_FORMAT = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_uuid?(instance.as_s)
    }

    URI_TEMPLATE = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_uri_template?(instance.as_s)
    }

    REGEX = ->(instance : JSON::Any, _format : String) {
      !instance.as_s? || valid_regex?(instance.as_s)
    }
  end
end
