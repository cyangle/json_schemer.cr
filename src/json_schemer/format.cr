module JsonSchemer
  # Module containing format validation logic.
  #
  # This module provides methods to validate strings against various formats
  # defined in the JSON Schema specification, such as "date-time", "email", "ipv4", etc.
  module Format
    # Regex patterns
    DATE_TIME_OFFSET_REGEX      = /(Z|[\+\-]([01][0-9]|2[0-3]):[0-5][0-9])\z/i
    DATE_TIME_SEPARATOR_CLASS   = "[Tt]"
    HOUR_24_REGEX               = /#{DATE_TIME_SEPARATOR_CLASS}24:/
    LEAP_SECOND_REGEX           = /#{DATE_TIME_SEPARATOR_CLASS}\d{2}:\d{2}:6/
    IP_REGEX                    = /\A[0-9a-fA-F:.]+\z/
    IRI_ESCAPE_REGEX            = /[^\x00-\x7F]/
    UUID_REGEX                  = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/
    NIL_UUID                    = "00000000-0000-0000-0000-000000000000"
    JSON_POINTER_REGEX          = /\A(\/([^~\/]|~[01])*)*\z/
    RELATIVE_JSON_POINTER_REGEX = /\A(0|[1-9]\d*)(#|(\/([^~\/]|~[01])*)*)\z/
    # RFC 3339 duration: integer components only (no fractional seconds), ordering constraints
    # are enforced in `valid_duration?`.
    DURATION_REGEX = /\AP([0-9]+Y)?([0-9]+M)?([0-9]+W)?([0-9]+D)?(T([0-9]+H)?([0-9]+M)?([0-9]+S)?)?\z/
    HOSTNAME_REGEX = /\A([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\z/
    EMAIL_REGEX    = /\A[^\s@]+@[^\s@]+\z/

    # RFC 6570 URI Template grammar
    URI_TEMPLATE_PCT_ENCODED = "%[0-9A-Fa-f]{2}"
    URI_TEMPLATE_VARCHAR     = "(?:[A-Za-z0-9_]|#{URI_TEMPLATE_PCT_ENCODED})"
    URI_TEMPLATE_VARNAME     = "(?:#{URI_TEMPLATE_VARCHAR}+(?:\\.(?:#{URI_TEMPLATE_VARCHAR})+)*)"
    URI_TEMPLATE_VARSPEC     = "(?:#{URI_TEMPLATE_VARNAME}(?:\\*|:[1-9][0-9]{0,3})?)"
    # RFC 6570 operator, including the reserved operators (= , ! @ |) from op-reserve.
    URI_TEMPLATE_EXPRESSION = "\\{[+#./;?&=,!@|]?#{URI_TEMPLATE_VARSPEC}(?:,#{URI_TEMPLATE_VARSPEC})*\\}"
    # RFC 6570 literals plus ucschar / iprivate. The apostrophe (0x27) is accepted
    # even though RFC 6570's ABNF omits it, because the JSON Schema test suite
    # requires it to be valid.
    URI_TEMPLATE_CHAR = "[\\x21\\x23-\\x24\\x26-\\x3B\\x3D\\x3F-\\x5B\\x5D\\x5F\\x61-\\x7A\\x7E" +
                        "\\x{A0}-\\x{D7FF}" +
                        "\\x{E000}-\\x{F8FF}" +
                        "\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFEF}" +
                        "\\x{10000}-\\x{1FFFD}\\x{20000}-\\x{2FFFD}\\x{30000}-\\x{3FFFD}" +
                        "\\x{40000}-\\x{4FFFD}\\x{50000}-\\x{5FFFD}\\x{60000}-\\x{6FFFD}" +
                        "\\x{70000}-\\x{7FFFD}\\x{80000}-\\x{8FFFD}\\x{90000}-\\x{9FFFD}" +
                        "\\x{A0000}-\\x{AFFFD}\\x{B0000}-\\x{BFFFD}\\x{C0000}-\\x{CFFFD}" +
                        "\\x{D0000}-\\x{DFFFD}" +
                        "\\x{E1000}-\\x{EFFFD}" +
                        "\\x{F0000}-\\x{FFFFD}\\x{100000}-\\x{10FFFD}]"
    URI_TEMPLATE_REGEX = /\A(?:#{URI_TEMPLATE_CHAR}|#{URI_TEMPLATE_PCT_ENCODED}|#{URI_TEMPLATE_EXPRESSION})*\z/

    # RFC 3339 date format: YYYY-MM-DD (exactly 4-digit year, 2-digit month, 2-digit day)
    DATE_REGEX = /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/
    # RFC 3339 time format: HH:MM:SS or HH:MM:SS.fraction with timezone (strict offset validation)
    TIME_REGEX = /\A[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[\+\-]([01][0-9]|2[0-3]):[0-5][0-9])\z/i
    # RFC 3339 date-time format with stricter timezone offset validation
    # Offset hours: 00-23, minutes: 00-59
    DATE_TIME_REGEX = /\A[0-9]{4}-[0-9]{2}-[0-9]{2}[Tt][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[\+\-]([01][0-9]|2[0-3]):[0-5][0-9])\z/i

    FRAGMENT_ENCODE_REGEX = ::JsonSchemer::FRAGMENT_ENCODE_REGEX

    # Validation constants
    MAX_HOUR            =  23
    MAX_MINUTE          =  59
    LEAP_SECOND         =  60
    MAX_HOSTNAME_LENGTH = 253

    # Code points that UTS 46 maps or allows but that IDNA2008 (RFC 5892) treats
    # specially: CONTEXTO, CONTEXTJ and the BackwardCompatible PVALID exceptions.
    # All of them are valid in an A-label's decoded U-label.
    IDNA2008_EXCEPTION_CHARS = Set{
      '\u00B7', '\u0375', '\u05F3', '\u05F4', '\u30FB',           # CONTEXTO
      '\u200C', '\u200D',                                         # CONTEXTJ
      '\u00DF', '\u03C2', '\u06FD', '\u06FE', '\u0F0B', '\u3007', # BackwardCompatible / PVALID
    }

    # Labels are separated by "." or one of the UTS 46 IDN label separators.
    IDN_LABEL_SEPARATOR_REGEX = /[.\x{3002}\x{FF0E}\x{FF61}]/

    # Format validator type
    alias FormatValidator = Proc(JSON::Any, String, Bool)

    # Percent encode helper
    def self.percent_encode(data : String, regexp : Regex) : String
      data.gsub(regexp) do |match|
        match.bytes.map { |byte| "%%%02X" % byte }.join
      end
    end

    # Validates a date-time string according to RFC 3339.
    #
    # Checks for correct format `YYYY-MM-DDTHH:MM:SSZ` or with offset,
    # valid ranges for date and time components, and handles leap seconds.
    def self.valid_date_time?(data : String) : Bool
      # Must match RFC 3339 format: YYYY-MM-DDTHH:MM:SS(.fraction)?(Z|+/-HH:MM)
      return false unless RegexpHelper.matches?(DATE_TIME_REGEX, data)

      # Check for hour 24 which is not valid in RFC 3339
      return false if data.includes?("T24:") || data.includes?("t24:")

      # Extract date and time parts
      date_part = data[0, 10]
      time_part_match = data.match(/[Tt](\d{2}):(\d{2}):(\d{2})/)
      return false unless time_part_match

      hour = time_part_match[1].to_i
      minute = time_part_match[2].to_i
      second = time_part_match[3].to_i

      # Validate date part
      return false unless valid_date?(date_part)

      # Validate time ranges
      return false if hour > MAX_HOUR
      return false if minute > MAX_MINUTE

      valid_leap_second?(data, hour, minute, second)
    end

    # Validates a full-date string according to RFC 3339.
    #
    # Format: `YYYY-MM-DD`.
    # Checks for valid year, month, and day, including leap years.
    def self.valid_date?(data : String) : Bool
      # Must match RFC 3339 date format exactly: YYYY-MM-DD
      return false unless RegexpHelper.matches?(DATE_REGEX, data)

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
      rescue ex : ArgumentError
        false
      end
    end

    # Check if year is a leap year
    private def self.leap_year?(year : Int32) : Bool
      (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    end

    # Validates a full-time string according to RFC 3339.
    #
    # Format: `HH:MM:SS` or with offset/Z.
    # Checks for valid hour, minute, and second, including leap seconds.
    def self.valid_time?(data : String) : Bool
      # Must match RFC 3339 time format
      return false unless RegexpHelper.matches?(TIME_REGEX, data)

      # Extract time parts
      time_match = data.match(/(\d{2}):(\d{2}):(\d{2})/)
      return false unless time_match

      hour = time_match[1].to_i
      minute = time_match[2].to_i
      second = time_match[3].to_i

      # Validate ranges
      return false if hour > 23
      return false if minute > 59

      valid_leap_second?(data, hour, minute, second)
    end

    # Validates a duration string according to ISO 8601.
    #
    # Format examples: `P1Y2M3DT4H5M6S`, `P1W`.
    def self.valid_duration?(data : String) : Bool
      # Must only use ASCII digits
      return false unless data.ascii_only?

      return false unless RegexpHelper.matches?(DURATION_REGEX, data)

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
        return false unless RegexpHelper.matches?(/\AP[0-9]+W\z/, data)
      end

      date_part = data
      time_part = ""
      if t_index = data.index('T')
        # If there's a T, make sure there's content after it
        time_part = data[(t_index + 1)..]? || ""
        return false if time_part.empty?
        date_part = data[0, t_index]
      end

      # RFC 3339 ordering constraints: years may not be followed by days unless
      # months are present ("P1Y2D"), and hours may not be followed by seconds
      # unless minutes are present ("PT1H2S").
      return false if date_part.includes?('Y') && date_part.includes?('D') && !date_part.includes?('M')
      return false if time_part.includes?('H') && time_part.includes?('S') && !time_part.includes?('M')

      true
    end

    # Validates an IP address (IPv4 or IPv6).
    def self.valid_ip?(data : String, family : Socket::Family) : Bool
      addr = Socket::IPAddress.new(data, 0)
      case family
      when Socket::Family::INET
        addr.family == Socket::Family::INET
      when Socket::Family::INET6
        addr.family == Socket::Family::INET6
      else
        false
      end
    rescue ex : Socket::Error
      false
    end

    # Characters disallowed in URIs per RFC 3986
    # These must be percent-encoded (note: [] allowed in host for IPv6)
    URI_DISALLOWED_CHARS = /[\x00-\x20\x7F<>"{}|\\^`]/

    # A '%' must always introduce a complete "%XX" triplet
    INVALID_PERCENT_ENCODING_REGEX = /%(?![0-9A-Fa-f]{2})/

    # RFC 3986 character classes
    URI_PCT_ENCODED = "%[0-9A-Fa-f]{2}"
    URI_UNRESERVED  = "[A-Za-z0-9\\-._~]"
    # sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
    URI_SUB_DELIMS = "[!$&'()*+,;=]"

    # pchar, and the same without ":" (for the first segment of a relative-path reference).
    URI_SEG_CHAR = "(?:#{URI_UNRESERVED}|#{URI_SUB_DELIMS}|[:@]|#{URI_PCT_ENCODED})"
    URI_SEG_NC   = "(?:#{URI_UNRESERVED}|#{URI_SUB_DELIMS}|[@]|#{URI_PCT_ENCODED})"

    # scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
    URI_SCHEME_REGEX = /\A[A-Za-z][A-Za-z0-9+\-.]*:/

    URI_PATH_ABEMPTY_REGEX  = /\A(?:\/#{URI_SEG_CHAR}*)*\z/
    URI_PATH_SCHEME_REGEX   = /\A(?:#{URI_SEG_CHAR}+(?:\/#{URI_SEG_CHAR}*)*|(?:\/#{URI_SEG_CHAR}*)*)\z/
    URI_PATH_NOSCHEME_REGEX = /\A(?:#{URI_SEG_NC}+(?:\/#{URI_SEG_CHAR}*)*|(?:\/#{URI_SEG_CHAR}*)*)\z/
    # query = *( pchar / "/" / "?" ); a fragment has the same grammar.
    URI_QUERY_REGEX    = /\A(?:#{URI_SEG_CHAR}|\/|\?)*\z/
    URI_FRAGMENT_REGEX = URI_QUERY_REGEX

    URI_USERINFO_REGEX = /\A(?:#{URI_UNRESERVED}|#{URI_SUB_DELIMS}|[:]|#{URI_PCT_ENCODED})*\z/
    URI_REG_NAME_REGEX = /\A(?:#{URI_UNRESERVED}|#{URI_SUB_DELIMS}|#{URI_PCT_ENCODED})*\z/

    # IPv4 octet without leading zeros (leading zeros are ambiguous / forbidden)
    URI_IPV4_OCTET      = "(?:0|[1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-5])"
    URI_IPV4_REGEX      = /\A#{URI_IPV4_OCTET}(?:\.#{URI_IPV4_OCTET}){3}\z/
    URI_H16_REGEX       = /\A[0-9A-Fa-f]{1,4}\z/
    URI_IPVFUTURE_REGEX = /\Av[0-9A-Fa-f]+\.[A-Za-z0-9\-._~!$&'()*+,;=:]+\z/

    # Validates a URI string according to RFC 3986.
    def self.valid_uri?(data : String) : Bool
      validate_uri_structure(data, require_scheme: true)
    end

    # Validates a URI reference string (relative or absolute).
    def self.valid_uri_reference?(data : String) : Bool
      validate_uri_structure(data, require_scheme: false)
    end

    # Shared URI/URI-reference validation following the RFC 3986 grammar.
    # The only difference is whether a non-empty scheme is required.
    private def self.validate_uri_structure(data : String, require_scheme : Bool) : Bool
      return false unless data.ascii_only?
      return false if RegexpHelper.matches?(URI_DISALLOWED_CHARS, data)
      return false if RegexpHelper.matches?(INVALID_PERCENT_ENCODING_REGEX, data)

      rest = data
      has_scheme = false
      if match = rest.match(URI_SCHEME_REGEX)
        has_scheme = true
        rest = rest[match[0].size..]? || ""
      elsif require_scheme
        return false
      end

      has_authority = false
      if rest.starts_with?("//")
        has_authority = true
        authority_end = rest.size
        {'/', '?', '#'}.each do |char|
          if (index = rest.index(char, 2)) && index < authority_end
            authority_end = index
          end
        end
        return false unless valid_uri_authority?(rest[2...authority_end])
        rest = rest[authority_end..]? || ""
      end

      fragment = nil
      if index = rest.index('#')
        fragment = rest[(index + 1)..]? || ""
        rest = rest[0...index]
      end
      query = nil
      if index = rest.index('?')
        query = rest[(index + 1)..]? || ""
        rest = rest[0...index]
      end

      path_ok =
        if has_authority
          RegexpHelper.matches?(URI_PATH_ABEMPTY_REGEX, rest)
        elsif has_scheme
          RegexpHelper.matches?(URI_PATH_SCHEME_REGEX, rest)
        else
          RegexpHelper.matches?(URI_PATH_NOSCHEME_REGEX, rest)
        end
      return false unless path_ok

      if query
        return false unless RegexpHelper.matches?(URI_QUERY_REGEX, query)
      end
      if fragment
        return false unless RegexpHelper.matches?(URI_FRAGMENT_REGEX, fragment)
      end

      true
    end

    # Validates the authority component: [userinfo "@"] host [":" port]
    private def self.valid_uri_authority?(authority : String) : Bool
      rest = authority
      if index = rest.index('@')
        return false unless RegexpHelper.matches?(URI_USERINFO_REGEX, rest[0...index])
        rest = rest[(index + 1)..]? || ""
      end

      host =
        if rest.starts_with?('[')
          close = rest.index(']')
          return false unless close
          remainder = rest[(close + 1)..]? || ""
          # Only an optional numeric port may follow the bracketed IP literal
          unless remainder.empty? || (remainder[0]? == ':' && RegexpHelper.matches?(/\A[0-9]*\z/, remainder[1..]? || ""))
            return false
          end
          rest[0..close]
        elsif index = rest.index(':')
          port = rest[(index + 1)..]? || ""
          return false unless RegexpHelper.matches?(/\A[0-9]*\z/, port)
          rest[0...index]
        else
          rest
        end

      valid_uri_host?(host)
    end

    # Validates a host: bracketed IP literal (strict IPv6 / IPvFuture) or reg-name.
    private def self.valid_uri_host?(host : String) : Bool
      if host.starts_with?('[')
        return false unless host.ends_with?(']')
        inner = host[1...-1]
        return true if RegexpHelper.matches?(URI_IPVFUTURE_REGEX, inner)
        valid_ipv6_address?(inner)
      else
        RegexpHelper.matches?(URI_REG_NAME_REGEX, host)
      end
    end

    # Strict RFC 3986 IPv6 address validation.
    # Unlike Socket::IPAddress, this rejects leading zeros in embedded IPv4
    # addresses (e.g. "::ffff:192.168.0.01").
    private def self.valid_ipv6_address?(address : String) : Bool
      groups = 0

      if index = address.index("::")
        # Only one "::" allowed, including overlapping occurrences (":::")
        remainder = address[(index + 1)..]? || ""
        return false if remainder.includes?("::")
        head = index == 0 ? "" : address[0, index]
        # An embedded IPv4 address (ls32) may only be the least significant 32 bits,
        # so it can never appear before the elision.
        return false if head.includes?('.')
        tail = index + 2 >= address.size ? "" : address[(index + 2)..]? || ""
        fields = (head.empty? ? [] of String : head.split(':', remove_empty: false)) +
                 (tail.empty? ? [] of String : tail.split(':', remove_empty: false))
        return false if fields.any? &.empty?
        max_groups = 7 # "::" must stand in for at least one group of zeros
      else
        fields = address.split(':', remove_empty: false)
        return false if fields.any? &.empty?
        max_groups = 8
      end

      last_index = fields.size - 1
      fields.each_with_index do |field, i|
        if field.includes?('.')
          # An embedded IPv4 address is only allowed as the final group
          return false unless i == last_index
          return false unless RegexpHelper.matches?(URI_IPV4_REGEX, field)
          groups += 2
        else
          return false unless RegexpHelper.matches?(URI_H16_REGEX, field)
          groups += 1
        end
      end

      max_groups == 8 ? groups == max_groups : groups <= max_groups
    end

    # IRI escape
    def self.iri_escape(data : String) : String
      percent_encode(data, IRI_ESCAPE_REGEX)
    end

    # Validates a JSON Pointer.
    def self.valid_json_pointer?(data : String) : Bool
      RegexpHelper.matches?(JSON_POINTER_REGEX, data)
    end

    # Validates a Relative JSON Pointer.
    def self.valid_relative_json_pointer?(data : String) : Bool
      RegexpHelper.matches?(RELATIVE_JSON_POINTER_REGEX, data)
    end

    # Validates a hostname.
    #
    # Checks for length limits, allowed characters, and structure (dot separation).
    # Supports Punycode encoded internationalized domain names (IDN) only when `with_simpleidn` flag is set.
    #
    # Raises `SimpleIDN::ConversionError` if an ICU system error occurs (when enabled).
    def self.valid_hostname?(data : String) : Bool
      # Hostname format requires ASCII-only string
      return false unless data.ascii_only?

      {% if flag?(:with_simpleidn) %}
        # Use SimpleIDN's hostname validation
        SimpleIDN.valid_hostname?(data)
      {% else %}
        RegexpHelper.matches?(HOSTNAME_REGEX, data) && data.size <= MAX_HOSTNAME_LENGTH
      {% end %}
    end

    # Validates an internationalized hostname (IDN).
    #
    # Converts to ASCII (Punycode) and validates as a hostname.
    # Requires `with_simpleidn` flag to work.
    #
    # Raises `SimpleIDN::ConversionError` if an ICU system error occurs.
    def self.valid_idn_hostname?(data : String) : Bool
      {% if flag?(:with_simpleidn) %}
        return false unless SimpleIDN.valid_hostname?(data)
        # UTS 46 permits some code points that IDNA2008 disallows (e.g. an A-label
        # that decodes to punctuation). Decode each A-label and require its code
        # points to be IDNA2008-valid.
        data.split(IDN_LABEL_SEPARATOR_REGEX).all? { |label| valid_idna2008_alabel?(label) }
      {% else %}
        Log.warn { "IDN hostname validation skipped because `with_simpleidn` flag is not set, always invalid" }
        false
      {% end %}
    end

    # Validates that an A-label (a label starting with "xn--"), when decoded,
    # contains only code points allowed by IDNA2008: letters, marks and numbers,
    # plus the CONTEXT/BackwardCompatible exceptions. This rejects the disallowed
    # punctuation/symbols that UTS 46 permits. Plain U-labels pass through.
    {% if flag?(:with_simpleidn) %}
      private def self.valid_idna2008_alabel?(label : String) : Bool
        return true unless label.downcase.starts_with?("xn--")

        decoded = SimpleIDN.to_unicode_hostname(label)
        return false unless decoded

        decoded.each_char.all? do |char|
          IDNA2008_EXCEPTION_CHARS.includes?(char) || char.letter? || char.mark? || char.number?
        end
      end
    {% end %}

    # Validates an email address.
    #
    # Checks for local part and domain part requirements according to RFC 5321/5322.
    def self.valid_email?(data : String) : Bool
      return false unless data.ascii_only?

      parts = parse_email_parts(data)
      return false unless parts
      local_part, domain_part = parts

      return false unless validate_local_part(local_part, allow_unicode: false)
      validate_domain_part(domain_part, allow_unicode: false)
    end

    # Validates an internationalized email address (IDN email).
    #
    # Allows Unicode characters in local part and domain part.
    def self.valid_idn_email?(data : String) : Bool
      parts = parse_email_parts(data)
      return false unless parts
      local_part, domain_part = parts

      return false unless validate_local_part(local_part, allow_unicode: true)
      validate_domain_part(domain_part, allow_unicode: true)
    end

    # Shared local part validation for email/IDN-email.
    # When `allow_unicode` is false, only ASCII characters are permitted.
    private def self.validate_local_part(local_part : String, allow_unicode : Bool) : Bool
      if local_part.starts_with?('"') && local_part.ends_with?('"')
        # Quoted string - allow most characters including spaces and @
        return false if local_part.size < 2
        inner = local_part[1...-1]
        return false if inner.includes?('\0')
      else
        # Unquoted local part
        return false if local_part.starts_with?('.') || local_part.ends_with?('.')
        return false if local_part.includes?("..")
        if allow_unicode
          # RFC 6531: atext =/ UTF8-non-ascii, so every non-ASCII code point is
          # allowed (no Unicode NFC normalization is required). ASCII characters
          # must still be valid atext.
          local_part.each_char do |char|
            next unless char.ascii?
            unless char.ascii_letter? || char.ascii_number? || ".!#$%&'*+/=?^_`{|}~-".includes?(char)
              return false
            end
          end
        else
          # ASCII-only: must only contain valid characters
          return false unless RegexpHelper.matches?(/\A[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+\z/, local_part)
        end
      end
      true
    end

    # Shared domain part validation for email/IDN-email.
    # When `allow_unicode` is false, validates as ASCII hostname;
    # when true, validates as IDN hostname.
    private def self.validate_domain_part(domain_part : String, allow_unicode : Bool) : Bool
      if domain_part.starts_with?('[') && domain_part.ends_with?(']')
        # IP address literal; the "IPv6:" tag is case-insensitive per RFC 5321
        ip_literal = domain_part[1...-1]
        if match = ip_literal.match(/\Aipv6:/i)
          valid_ip?(ip_literal[match[0].size..]? || "", Socket::Family::INET6)
        else
          valid_ip?(ip_literal, Socket::Family::INET)
        end
      else
        if allow_unicode
          valid_idn_hostname?(domain_part)
        else
          return false if domain_part.includes?('=')
          valid_hostname?(domain_part)
        end
      end
    end

    # Validates a UUID.
    def self.valid_uuid?(data : String) : Bool
      RegexpHelper.matches?(UUID_REGEX, data)
    end

    # Validates a URI Template (RFC 6570).
    def self.valid_uri_template?(data : String) : Bool
      RegexpHelper.matches?(URI_TEMPLATE_REGEX, data)
    end

    # Validates a regular expression (ECMA-262).
    def self.valid_regex?(data : String) : Bool
      EcmaRegexp.valid?(data)
    end

    private def self.valid_leap_second?(data : String, hour : Int32, minute : Int32, second : Int32) : Bool
      # Handle leap seconds (second = 60)
      if second == LEAP_SECOND
        # Leap seconds are only valid at 23:59 UTC

        # Extract offset to determine if this could be a valid leap second
        if data.includes?("Z") || data.includes?("z")
          # UTC time: must be 23:59:60
          return false unless hour == MAX_HOUR && minute == MAX_MINUTE
        else
          # With offset, the local time must be such that UTC is 23:59
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

            return false unless utc_hour == MAX_HOUR && utc_minute == MAX_MINUTE
          else
            return false
          end
        end
      elsif second > MAX_MINUTE
        return false
      end

      true
    end

    private def self.parse_email_parts(data : String) : {String, String}?
      local_part : String
      domain_part : String

      if data.starts_with?('"')
        # Quoted local part - find unescaped closing quote then @
        closing_quote = nil
        i = 1
        while i < data.size
          if data[i] == '\\'
            i += 2 # Skip escaped character
            next
          elsif data[i] == '"'
            closing_quote = i
            break
          end
          i += 1
        end

        return nil unless closing_quote
        return nil unless closing_quote + 1 < data.size && data[closing_quote + 1] == '@'

        local_part = data[0..closing_quote]
        domain_part = data[(closing_quote + 2)..]
      else
        # Unquoted - simple split
        at_index = data.index('@')
        return nil unless at_index

        local_part = data[0...at_index]
        domain_part = data[(at_index + 1)..]
      end

      return nil if local_part.empty? || domain_part.empty?
      {local_part, domain_part}
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
      !instance.as_s? || valid_hostname?(instance.as_s)
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
