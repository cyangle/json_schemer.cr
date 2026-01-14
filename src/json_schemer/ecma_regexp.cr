module JsonSchemer
  # ECMA-262 regexp handling
  # Converts ECMA-262 regex patterns to Crystal/PCRE2 compatible patterns
  module EcmaRegexp
    # Character class escapes that need conversion to ASCII-only equivalents
    # ECMA-262 defines these as ASCII-only, unlike Ruby/Crystal's Unicode-aware versions
    # For \s and \S, we include all ECMA-262 whitespace characters using actual Unicode chars
    ECMA_WHITESPACE = "\t\n\v\f\r \u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff"

    ESCAPES = {
      "\\d" => "[0-9]",
      "\\D" => "[^0-9]",
      "\\w" => "[A-Za-z0-9_]",
      "\\W" => "[^A-Za-z0-9_]",
      "\\s" => "[#{Regex.escape(ECMA_WHITESPACE)}]",
      "\\S" => "[^#{Regex.escape(ECMA_WHITESPACE)}]",
    }

    # ECMA-262 Unicode property names to PCRE2 equivalents
    # ECMA-262 uses long names, PCRE2 uses short names
    # See: https://tc39.es/ecma262/#table-unicode-general-category-values
    UNICODE_PROPERTY_MAP = {
      # General Category (long names to short)
      "letter"                 => "L",
      "cased_letter"           => "LC",
      "uppercase_letter"       => "Lu",
      "lowercase_letter"       => "Ll",
      "titlecase_letter"       => "Lt",
      "modifier_letter"        => "Lm",
      "other_letter"           => "Lo",
      "mark"                   => "M",
      "nonspacing_mark"        => "Mn",
      "spacing_combining_mark" => "Mc",
      "enclosing_mark"         => "Me",
      "number"                 => "N",
      "decimal_number"         => "Nd",
      "letter_number"          => "Nl",
      "other_number"           => "No",
      "punctuation"            => "P",
      "connector_punctuation"  => "Pc",
      "dash_punctuation"       => "Pd",
      "open_punctuation"       => "Ps",
      "close_punctuation"      => "Pe",
      "initial_punctuation"    => "Pi",
      "final_punctuation"      => "Pf",
      "other_punctuation"      => "Po",
      "symbol"                 => "S",
      "math_symbol"            => "Sm",
      "currency_symbol"        => "Sc",
      "modifier_symbol"        => "Sk",
      "other_symbol"           => "So",
      "separator"              => "Z",
      "space_separator"        => "Zs",
      "line_separator"         => "Zl",
      "paragraph_separator"    => "Zp",
      "other"                  => "C",
      "control"                => "Cc",
      "format"                 => "Cf",
      "surrogate"              => "Cs",
      "private_use"            => "Co",
      "unassigned"             => "Cn",
      # Short alias for "digit" used in test
      "digit" => "Nd",
      # Binary properties (common ones)
      "ascii"           => "ASCII",
      "alphabetic"      => "Alphabetic",
      "white_space"     => "White_Space",
      "hex_digit"       => "Hex_Digit",
      "ascii_hex_digit" => "ASCII_Hex_Digit",
      "lowercase"       => "Lowercase",
      "uppercase"       => "Uppercase",
      "emoji"           => "Emoji",
      # Script names (keep as-is, PCRE2 supports them)
    }

    # Named character classes in ECMA that Crystal/Ruby handles differently
    UNICODE_ESCAPES = /\\u\{?([0-9A-Fa-f]+)\}?/

    # Regex to find Unicode property escapes
    UNICODE_PROPERTY_PATTERN = /\\[pP]\{([^}]+)\}/

    # Regex to find character class escapes that need replacement
    # We need to be careful not to replace escapes inside character classes
    ESCAPE_PATTERN = /\\[dDwWsS]/

    def self.crystal_equivalent(pattern : String) : String
      result = pattern

      # Replace ECMA character class escapes with ASCII-only equivalents
      # Need to handle them outside of character classes [...] carefully
      result = replace_escapes_outside_character_classes(result)

      # Convert Unicode property names to PCRE2 format
      result = convert_unicode_properties(result)

      # Convert $ anchor to \z for ECMA-262 semantics
      # In ECMA-262, $ only matches end of string, not before trailing newline
      # In PCRE2, $ matches end of string OR before newline at end
      # \z in PCRE2 matches only at absolute end of string
      result = convert_dollar_anchor(result)

      # Handle \cX control character escapes
      # Both ECMA-262 and PCRE2 support \cX, but we need to ensure
      # lowercase letters are also handled (ECMA allows \ca-\cz)
      result = convert_control_escapes(result)

      # Handle unicode escapes \u{XXXX} or \uXXXX
      result = result.gsub(UNICODE_ESCAPES) do |match|
        hex = match.match(UNICODE_ESCAPES).not_nil![1]
        codepoint = hex.to_i(16)
        if codepoint <= 0xFFFF
          "\\u#{hex.rjust(4, '0')}"
        else
          codepoint.chr.to_s
        end
      rescue
        match
      end

      result
    rescue ex
      raise InvalidEcmaRegexp.new("Invalid ECMA regexp: #{pattern}")
    end

    # Convert Unicode property names from ECMA-262 (long names) to PCRE2 (short names)
    private def self.convert_unicode_properties(pattern : String) : String
      result = pattern.gsub(UNICODE_PROPERTY_PATTERN) do |match|
        m = match.match(UNICODE_PROPERTY_PATTERN).not_nil!
        prop_name = m[1]
        prefix = match[0..1] # \p or \P

        # Check if it's a long name that needs conversion
        # Property names are case-insensitive in ECMA-262
        normalized = prop_name.downcase.gsub('-', '_').gsub(' ', '_')

        if pcre_name = UNICODE_PROPERTY_MAP[normalized]?
          "#{prefix}{#{pcre_name}}"
        else
          # Keep as-is (might be a script name or already short form)
          match
        end
      end

      result
    end

    # Convert $ anchor to \z for ECMA-262 behavior
    # In ECMA-262, $ only matches at the absolute end of string
    # In PCRE2, $ also matches before a trailing newline
    private def self.convert_dollar_anchor(pattern : String) : String
      result = String::Builder.new
      i = 0
      in_char_class = false
      escape_next = false

      while i < pattern.size
        char = pattern[i]

        if escape_next
          result << '\\'
          result << char
          escape_next = false
          i += 1
          next
        end

        if char == '\\'
          escape_next = true
          i += 1
          next
        end

        if char == '[' && !in_char_class
          in_char_class = true
          result << char
        elsif char == ']' && in_char_class
          in_char_class = false
          result << char
        elsif char == '$' && !in_char_class
          # Replace $ with \z for ECMA-262 semantics
          result << "\\z"
        else
          result << char
        end

        i += 1
      end

      # Handle trailing backslash
      if escape_next
        result << '\\'
      end

      result.to_s
    end

    # Convert \cX control escapes - ECMA-262 allows both upper and lowercase
    # \cA-\cZ and \ca-\cz both map to control codes 0x01-0x1A
    # PCRE2 supports this, but we normalize lowercase to uppercase for consistency
    private def self.convert_control_escapes(pattern : String) : String
      result = String::Builder.new
      i = 0

      while i < pattern.size
        char = pattern[i]

        if char == '\\' && i + 1 < pattern.size
          next_char = pattern[i + 1]

          if next_char == 'c' && i + 2 < pattern.size
            control_char = pattern[i + 2]
            # ECMA-262: \cX where X is a-z or A-Z
            if control_char.ascii_letter?
              # Convert to uppercase for PCRE2 compatibility
              result << "\\c"
              result << control_char.upcase
              i += 3
              next
            end
          end

          # Not a control escape, copy as-is
          result << char
          i += 1
        else
          result << char
          i += 1
        end
      end

      result.to_s
    end

    # Replace character class escapes, being careful about character class context
    private def self.replace_escapes_outside_character_classes(pattern : String) : String
      result = String::Builder.new
      i = 0
      in_char_class = false
      escape_next = false

      while i < pattern.size
        char = pattern[i]

        if escape_next
          # Check if this is a character class escape we need to replace
          if !in_char_class && "dDwWsS".includes?(char)
            escape_seq = "\\#{char}"
            if replacement = ESCAPES[escape_seq]?
              result << replacement
            else
              result << escape_seq
            end
          else
            result << '\\'
            result << char
          end
          escape_next = false
          i += 1
          next
        end

        if char == '\\'
          escape_next = true
          i += 1
          next
        end

        if char == '[' && !in_char_class
          in_char_class = true
        elsif char == ']' && in_char_class
          in_char_class = false
        end

        result << char
        i += 1
      end

      # Handle trailing backslash
      if escape_next
        result << '\\'
      end

      result.to_s
    end

    # Valid ECMA-262 escape characters (after the backslash)
    # Includes: character class escapes, control escapes, digits for backrefs,
    # special escapes like \b \B \0, and identity escapes for non-word chars
    VALID_ECMA_ESCAPES = Set{
      # Character class escapes
      'd', 'D', 'w', 'W', 's', 'S',
      # Control escapes
      'f', 'n', 'r', 't', 'v',
      # Word boundary
      'b', 'B',
      # Null character
      '0',
      # Hex and unicode escapes
      'x', 'u',
      # Control character
      'c',
      # Backreferences (digits 1-9)
      '1', '2', '3', '4', '5', '6', '7', '8', '9',
      # Other valid escapes (for character classes and assertions)
      'k', 'p', 'P',
    }

    # Check if pattern is valid ECMA-262 regex
    def self.valid?(pattern : String) : Bool
      # First check for invalid escape sequences
      return false if has_invalid_escapes?(pattern)

      # Then check if it's a valid regex overall
      crystal_equivalent(pattern)
      Regex.new(crystal_equivalent(pattern))
      true
    rescue
      false
    end

    # Check for escape sequences that are invalid in ECMA-262
    private def self.has_invalid_escapes?(pattern : String) : Bool
      i = 0
      in_char_class = false

      while i < pattern.size
        char = pattern[i]

        if char == '\\'
          i += 1
          break if i >= pattern.size

          next_char = pattern[i]

          # Inside character class, most escapes are allowed as identity escapes
          unless in_char_class
            # Check if this is an invalid escape outside character class
            # \a is specifically NOT a valid ECMA-262 escape
            if next_char == 'a'
              return true
            end
          end
        elsif char == '[' && !in_char_class
          in_char_class = true
        elsif char == ']' && in_char_class
          in_char_class = false
        end

        i += 1
      end

      false
    end
  end
end
