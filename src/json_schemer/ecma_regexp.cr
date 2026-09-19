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

    # Inner content for \s replacement inside character classes (no outer brackets)
    ECMA_WHITESPACE_INNER = Regex.escape(ECMA_WHITESPACE)

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

    # Separate patterns for braced and unbraced unicode escapes
    # Braced: \u{XXXX} or \u{XXXXX} (variable length hex)
    UNICODE_ESCAPE_BRACED = /\\u\{([0-9A-Fa-f]+)\}/
    # Unbraced: \uXXXX (exactly 4 hex digits)
    UNICODE_ESCAPE_UNBRACED = /\\u([0-9A-Fa-f]{4})/

    # Regex to find Unicode property escapes
    UNICODE_PROPERTY_PATTERN = /\\[pP]\{([^}]+)\}/

    # Regex to find character class escapes that need replacement
    # We need to be careful not to replace escapes inside character classes
    ESCAPE_PATTERN = /\\[dDwWsS]/

    def self.crystal_equivalent(pattern : String) : String
      # Step 0: Reject invalid escape sequences
      if has_invalid_escapes?(pattern)
        raise InvalidEcmaRegexp.new("Invalid ECMA regexp: contains invalid escape sequence")
      end

      # Step 0b: Reject group syntax that exists in Ruby/PCRE but not ECMA-262:
      # (?P<name>), (?P=name), (?'name>, (?#comment), and bare inline flags like (?i).
      if has_non_ecma_groups?(pattern)
        raise InvalidEcmaRegexp.new("Invalid ECMA regexp: contains non-ECMA group syntax")
      end

      result = pattern

      # Step 0c: ECMA-262 treats [] as a never-matching character class and [^] as
      # matching any character. PCRE2 would treat the leading ']' as a plain member,
      # leaving these classes unterminated, so rewrite them.
      result = normalize_empty_char_classes(result)

      # Step 0d: ECMA-262 allows unbounded quantifiers inside variable-width
      # lookbehinds; PCRE2 requires a bounded maximum length, so bound them.
      result = bound_lookbehind_quantifiers(result)

      # Step 1: Replace ECMA character class escapes (\d, \w, \s, etc.)
      # with ASCII-only equivalents, only outside [...] character classes
      result = replace_escapes_outside_character_classes(result)

      # Step 2: Convert Unicode property names from ECMA-262 long form to PCRE2 short form
      result = convert_unicode_properties(result)

      # Step 3: Convert $ anchor to \z for ECMA-262 semantics
      # (ECMA: end of string only; PCRE2 $: also matches before trailing newline)
      result = convert_dollar_anchor(result)

      # Step 4: Normalize \cX control character escapes (ECMA allows lowercase \ca-\cz)
      result = convert_control_escapes(result)

      # Step 5: Convert unicode escapes to PCRE2-compatible \x{XXXX} format
      # (PCRE2 does not support \u — only \x{XXXX})

      # Step 5a: Convert braced form \u{XXXX} or \u{XXXXX}
      result = result.gsub(UNICODE_ESCAPE_BRACED) do |match|
        hex = match.match!(UNICODE_ESCAPE_BRACED)[1]
        codepoint = hex.to_i(16)
        if codepoint <= 0xFFFF
          "\\x{#{hex.rjust(4, '0')}}"
        else
          codepoint.chr.to_s
        end
      rescue ex : ArgumentError | OverflowError
        match
      end

      # Step 5b: Convert unbraced form \uXXXX (exactly 4 hex digits)
      result = result.gsub(UNICODE_ESCAPE_UNBRACED) do |match|
        hex = match.match!(UNICODE_ESCAPE_UNBRACED)[1]
        "\\x{#{hex}}"
      rescue ex : ArgumentError | OverflowError
        match
      end

      result
    rescue ex : Exception
      Log.debug { "ECMA regexp conversion failed for pattern: #{pattern}, error: #{ex.message}" }
      raise InvalidEcmaRegexp.new("Invalid ECMA regexp: #{pattern}")
    end

    # Convert Unicode property names from ECMA-262 (long names) to PCRE2 (short names)
    private def self.convert_unicode_properties(pattern : String) : String
      result = pattern.gsub(UNICODE_PROPERTY_PATTERN) do |match|
        m = match.match!(UNICODE_PROPERTY_PATTERN)
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

    # Walks a regex pattern character-by-character, tracking escape state and
    # character class depth. Yields (char, escaped, in_char_class) for each
    # character. This is the shared state machine used by multiple conversion
    # methods to avoid reimplementing the same boilerplate.
    #
    # - `escaped`: true when the character follows a backslash
    # - `in_char_class`: true when inside [...]
    #
    # The block receives each character exactly once. Backslash characters that
    # start an escape sequence are NOT yielded — only the escaped character is
    # yielded (with `escaped = true`).
    private def self.walk_pattern(pattern : String, &)
      char_class_depth = 0
      escape_next = false

      pattern.each_char do |char|
        if escape_next
          yield char, true, char_class_depth > 0
          escape_next = false
          next
        end

        if char == '\\'
          escape_next = true
          next
        end

        if char == '['
          char_class_depth += 1
        elsif char == ']' && char_class_depth > 0
          char_class_depth -= 1
        end

        yield char, false, char_class_depth > 0
      end
      # Signal trailing backslash (incomplete escape)
      if escape_next
        yield '\\', false, char_class_depth > 0
      end
    end

    # Convert $ anchor to \z for ECMA-262 behavior
    # In ECMA-262, $ only matches at the absolute end of string
    # In PCRE2, $ also matches before a trailing newline
    private def self.convert_dollar_anchor(pattern : String) : String
      result = String::Builder.new
      walk_pattern(pattern) do |char, escaped, in_char_class|
        if escaped
          result << '\\'
          result << char
        elsif char == '$' && !in_char_class
          result << "\\z"
        else
          result << char
        end
      end
      result.to_s
    end

    # Convert \cX control escapes - ECMA-262 allows both upper and lowercase
    # \cA-\cZ and \ca-\cz both map to control codes 0x01-0x1A
    # PCRE2 supports this, but we normalize lowercase to uppercase for consistency
    private def self.convert_control_escapes(pattern : String) : String
      result = String::Builder.new
      i = 0
      escape_next = false

      while i < pattern.size
        char = pattern[i]

        if escape_next
          if char == 'c' && i + 1 < pattern.size
            control_char = pattern[i + 1]
            if control_char.ascii_letter?
              result << "\\c" << control_char.upcase
              escape_next = false
              i += 2
              next
            end
          end
          result << '\\' << char
          escape_next = false
          i += 1
          next
        end

        if char == '\\'
          escape_next = true
          i += 1
          next
        end

        result << char
        i += 1
      end

      if escape_next
        result << '\\'
      end

      result.to_s
    end

    # Replace character class escapes (\d, \w, \s, etc.) with ASCII-only equivalents
    # Handles both inside and outside [...] character classes
    private def self.replace_escapes_outside_character_classes(pattern : String) : String
      result = String::Builder.new
      walk_pattern(pattern) do |char, escaped, in_char_class|
        if escaped
          if "dDwWsS".includes?(char)
            if in_char_class
              # Inside [...], use bracket-free equivalents for positive escapes
              # to ensure ASCII-only behavior (PCRE2's \d etc. are Unicode-aware)
              case char
              when 'd' then result << "0-9"
              when 'w' then result << "A-Za-z0-9_"
              when 's' then result << ECMA_WHITESPACE_INNER
              else
                # \D, \W, \S inside char class: leave as-is
                # (negated forms can't be cleanly expanded inside bracket unions)
                result << '\\' << char
              end
            else
              escape_seq = "\\#{char}"
              if replacement = ESCAPES[escape_seq]?
                result << replacement
              else
                result << escape_seq
              end
            end
          else
            result << '\\'
            result << char
          end
        else
          result << char
        end
      end
      result.to_s
    end

    # Check if pattern is valid ECMA-262 regex
    def self.valid?(pattern : String) : Bool
      # First check for invalid escape sequences
      return false if has_invalid_escapes?(pattern)

      # Then check if it's a valid regex overall
      converted = crystal_equivalent(pattern)
      begin
        Regex.new(converted)
        true
      rescue ex : ArgumentError
        # PCRE2 rejects variable-width lookbehind branches that exceed its maximum
        # length, but ECMA-262 allows them; such a pattern is valid ECMA.
        lookbehind_engine_limit?(ex)
      end
    rescue ex : InvalidEcmaRegexp
      false
    end

    # True when a compile failure is caused by PCRE2's lookbehind length limit
    # rather than an actually malformed ECMA-262 pattern.
    private def self.lookbehind_engine_limit?(error : ArgumentError) : Bool
      message = error.message || ""
      message.includes?("lookbehind") &&
        (message.includes?("not limited") ||
          message.includes?("branch too long") ||
          message.includes?("not fixed length"))
    end

    # Check for escape sequences that are invalid in ECMA-262
    private def self.has_invalid_escapes?(pattern : String) : Bool
      walk_pattern(pattern) do |char, escaped, in_char_class|
        # Inside character class, most escapes are allowed as identity escapes.
        # Outside: \a is specifically NOT a valid ECMA-262 escape.
        if escaped && !in_char_class && char.ascii_letter? && !VALID_ECMA_ESCAPES.includes?(char)
          return true
        end
      end
      false
    end

    # Group syntax that exists in PCRE but not in ECMA-262 must be rejected:
    # (?P<name>...), (?P=name), (?'name'...), (?#comment), atomic groups (?>...),
    # branch reset (?|...), conditionals (?(...)...), subroutines/recursion
    # ((?R), (?0..(?9, (?&name), (?+n)) and bare global inline flags such as (?i).
    # ECMA-262 flag groups require a colon: (?im:x). Possessive quantifiers
    # (a++, a*+, a?+, a{m,n}+) are also not part of ECMA-262.
    private def self.has_non_ecma_groups?(pattern : String) : Bool
      chars = pattern.chars
      in_char_class = false
      i = 0
      while i < chars.size
        case chars[i]
        when '\\'
          i += 2
          next
        when '['
          in_char_class = true
        when ']'
          in_char_class = false
        when '('
          # A literal '(' inside a character class never opens a group
          return true unless in_char_class || valid_ecma_group_open?(chars, i)
        when '+'
          return true if !in_char_class && possessive_quantifier?(chars, i)
        end
        i += 1
      end
      false
    end

    # Checks that a group opening at index `i` (a '(' character) uses ECMA-262 syntax.
    private def self.valid_ecma_group_open?(chars : Array(Char), i : Int32) : Bool
      return true if chars[i + 1]? != '?'

      case chars[i + 2]?
      when ':', '=', '!', '<'
        # (?:x) (?=x) (?!x) (?<=x) (?<!x) (?<name>x) -- all valid ECMA-262
        true
      when 'P', '#', '\'', '>', '(', '|', '&', '+', 'R', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
        # PCRE-only group constructs; none of these exist in ECMA-262.
        false
      else
        # A flag group is only valid with a colon, e.g. (?im:x); bare (?i) is invalid.
        j = i + 2
        while (flag = chars[j]?) && "imsxuUdDgG-".includes?(flag)
          j += 1
        end
        j > i + 2 && chars[j]? == ':'
      end
    end

    # True when the '+' at `index` is a possessive quantifier suffix (a++, a*+, a?+,
    # a{m,n}+), which is a PCRE extension not present in ECMA-262.
    private def self.possessive_quantifier?(chars : Array(Char), index : Int32) : Bool
      return false if index.zero?
      case chars[index - 1]?
      when '+', '*', '?'
        true
      when '}'
        closing_interval_brace?(chars, index - 1)
      else
        false
      end
    end

    # True when the '}' at `close_index` closes a valid `{m}` / `{m,}` / `{m,n}`
    # interval quantifier (and is not itself escaped).
    private def self.closing_interval_brace?(chars : Array(Char), close_index : Int32) : Bool
      return false if close_index.zero? || chars[close_index - 1]? == '\\'

      open_index = chars.rindex('{', close_index)
      return false unless open_index
      return false if open_index > 0 && chars[open_index - 1]? == '\\'

      spec = chars[(open_index + 1)...close_index].join
      spec.matches?(/\A\d+(,\d*)?\z/)
    end

    # ECMA-262 empty character classes: [] never matches anything, and [^] matches
    # every character (including line terminators). Unlike PCRE, ECMA-262 does not
    # treat a leading ']' as an ordinary class member, so `]` always terminates the
    # class; rewrite the two empty forms to PCRE2 equivalents.
    private def self.normalize_empty_char_classes(pattern : String) : String
      return pattern unless pattern.includes?('[')

      chars = pattern.chars
      result = String::Builder.new
      in_char_class = false
      i = 0
      while i < chars.size
        char = chars[i]
        if char == '\\'
          result << char
          if i + 1 < chars.size
            result << chars[i + 1]
            i += 2
          else
            i += 1
          end
          next
        end

        if in_char_class
          in_char_class = false if char == ']'
          result << char
          i += 1
          next
        end

        if char == '['
          negated = chars[i + 1]? == '^'
          closing = negated ? i + 2 : i + 1
          if chars[closing]? == ']'
            # (?! ) never matches; (?:.|\n) matches every character.
            result << (negated ? "(?:.|\\n)" : "(?!)")
            i = closing + 1
          else
            in_char_class = true
            result << char
            i += 1
          end
        else
          result << char
          i += 1
        end
      end
      result.to_s
    end

    # ECMA-262 permits unbounded quantifiers inside variable-width lookbehinds.
    # PCRE2 requires each variable-length branch of a lookbehind to have a bounded
    # maximum length (255 code units by default), so unbounded quantifiers within
    # lookbehinds are rewritten to the largest bounded form that still fits. This is
    # an approximation: a branch that cannot fit is left untouched and reported as
    # valid ECMA by `valid?` even though PCRE2 cannot compile it.
    private def self.bound_lookbehind_quantifiers(pattern : String) : String
      return pattern unless pattern.includes?("(?<=") || pattern.includes?("(?<!")

      result = String::Builder.new
      i = 0
      in_char_class = false
      while i < pattern.size
        char = pattern[i]
        if char == '\\'
          result << char
          escaped_char = pattern[i + 1]?
          if escaped_char
            result << escaped_char
            i += 2
          else
            i += 1
          end
          next
        end

        if in_char_class
          in_char_class = false if char == ']'
          result << char
          i += 1
          next
        end

        if char == '['
          in_char_class = true
          result << char
          i += 1
          next
        end

        if char == '(' && pattern[i + 1]? == '?' && pattern[i + 2]? == '<' && (pattern[i + 3]? == '=' || pattern[i + 3]? == '!')
          close = matching_paren(pattern, i)
          if close
            inner = pattern[(i + 4)...close]? || ""
            base, count = lookbehind_metrics(inner)
            bounded_inner =
              if count.zero? || base >= 255
                # Nothing to bound, or the minimum length already exceeds the limit.
                inner
              else
                bound_quantifiers(inner, Math.max(1, (255 - base) // count))
              end
            result << "(?<" << pattern[i + 3] << bounded_inner << ')'
            i = close + 1
            next
          end
        end

        result << char
        i += 1
      end
      result.to_s
    end

    # Returns the index of the ')' matching the '(' at index `i`, or nil if unbalanced.
    private def self.matching_paren(pattern : String, i : Int32) : Int32?
      depth = 0
      in_class = false
      j = i
      while j < pattern.size
        char = pattern[j]
        if char == '\\'
          j += 2
          next
        end

        if in_class
          in_class = false if char == ']'
        elsif char == '['
          in_class = true
        elsif char == '('
          depth += 1
        elsif char == ')'
          depth -= 1
          return j if depth.zero?
        end
        j += 1
      end
      nil
    end

    # Estimates the minimum length and the number of unbounded quantifiers of a
    # lookbehind branch, so a safe per-quantifier bound can be computed.
    private def self.lookbehind_metrics(inner : String) : {Int32, Int32}
      base = 0
      count = 0
      i = 0
      while i < inner.size
        char = inner[i]
        case char
        when '\\'
          escaped = inner[i + 1]?
          if escaped && "bBAzZG".includes?(escaped)
            i += 2
          elsif escaped == 'p' || escaped == 'P' || escaped == 'k'
            base += 1
            i += 2
            if (open = inner[i]?) && (open == '{' || open == '<')
              closer = open == '{' ? '}' : '>'
              i += 1
              while i < inner.size && inner[i] != closer
                i += 1
              end
              i += 1
            end
          else
            base += 1
            i += 2
          end
        when '['
          base += 1
          i += 1
          i += 1 if inner[i]? == '^'
          i += 1 if inner[i]? == ']'
          while i < inner.size
            current = inner[i]
            if current == '\\'
              i += 2
            elsif current == ']'
              i += 1
              break
            else
              i += 1
            end
          end
        when '(', ')', '|', '^', '$', '?'
          i += 1
        when '+', '*'
          count += 1
          i += 1
        when '{'
          close = inner.index('}', i)
          spec = close ? (inner[(i + 1)...close]? || "") : ""
          if spec.matches?(/\A\d+(,\d*)?\z/)
            base += spec.split(',')[0].to_i
            count += 1 if spec.ends_with?(',')
            i = (close || i) + 1
          else
            base += 1
            i += 1
          end
        else
          base += 1
          i += 1
        end
      end
      {base, count}
    end

    # Rewrites unbounded quantifiers ('+', '*', '{m,}') in lookbehind content to
    # bounded forms using the given per-quantifier slack `cap`.
    private def self.bound_quantifiers(inner : String, cap : Int32) : String
      result = String::Builder.new
      in_class = false
      i = 0
      while i < inner.size
        char = inner[i]
        if char == '\\'
          result << char
          escaped_char = inner[i + 1]?
          if escaped_char
            result << escaped_char
            i += 2
          else
            i += 1
          end
          next
        end

        if in_class
          in_class = false if char == ']'
          result << char
          i += 1
          next
        end

        case char
        when '['
          in_class = true
          result << char
          i += 1
        when '+'
          result << "{1,#{1 + cap}}"
          i += 1
        when '*'
          result << "{0,#{cap}}"
          i += 1
        when '{'
          if (close = inner.index('}', i)) && (spec = inner[(i + 1)...close]?)
            if spec.matches?(/\A\d+(,\d*)?\z/) && spec.ends_with?(',')
              min = spec.split(',')[0].to_i
              result << "{#{min},#{min + cap}}"
              i = close + 1
            else
              result << char
              i += 1
            end
          else
            result << char
            i += 1
          end
        else
          result << char
          i += 1
        end
      end
      result.to_s
    end
  end
end
