require "./spec_helper"

describe JsonSchemer::EcmaRegexp do
  describe ".crystal_equivalent" do
    # =========================================================================
    # 1. Character class escape conversion OUTSIDE character classes
    # =========================================================================
    describe "character class escapes outside [...]" do
      it "converts \\d to [0-9]" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\d").should eq("[0-9]")
      end

      it "converts \\D to [^0-9]" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\D").should eq("[^0-9]")
      end

      it "converts \\w to [A-Za-z0-9_]" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\w").should eq("[A-Za-z0-9_]")
      end

      it "converts \\W to [^A-Za-z0-9_]" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\W").should eq("[^A-Za-z0-9_]")
      end

      it "converts \\s to ECMA whitespace character class" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\s")
        result.should start_with("[")
        result.should end_with("]")
        re = Regex.new(result)
        # Standard whitespace
        (re =~ " ").should_not be_nil
        (re =~ "\t").should_not be_nil
        (re =~ "\n").should_not be_nil
        (re =~ "\r").should_not be_nil
        # ECMA-specific whitespace
        (re =~ "\u00a0").should_not be_nil # non-breaking space
        (re =~ "\ufeff").should_not be_nil # BOM
      end

      it "converts \\S to negated ECMA whitespace character class" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\S")
        result.should start_with("[^")
        result.should end_with("]")
        re = Regex.new(result)
        (re =~ " ").should be_nil
        (re =~ "\t").should be_nil
        (re =~ "a").should_not be_nil
        (re =~ "1").should_not be_nil
      end

      it "\\d is ASCII-only: does NOT match Unicode digits" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\d")
        re = Regex.new(result)
        # Arabic-Indic digit zero U+0660
        (re =~ "\u0660").should be_nil
        # Devanagari digit zero U+0966
        (re =~ "\u0966").should be_nil
        # ASCII digits must match
        (re =~ "0").should_not be_nil
        (re =~ "9").should_not be_nil
      end

      it "\\w is ASCII-only: does NOT match Unicode letters" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\w")
        re = Regex.new(result)
        (re =~ "é").should be_nil
        (re =~ "中").should be_nil
        (re =~ "a").should_not be_nil
        (re =~ "Z").should_not be_nil
        (re =~ "_").should_not be_nil
        (re =~ "5").should_not be_nil
      end

      it "handles multiple escapes in one pattern" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\d\\w")
        result.should eq("[0-9][A-Za-z0-9_]")
      end

      it "combines escapes with literals" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("a\\db").should eq("a[0-9]b")
      end

      it "handles \\d in complex pattern" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("^\\d{3}-\\d{4}$")
        result.should eq("^[0-9]{3}-[0-9]{4}\\z")
        re = Regex.new(result)
        (re =~ "123-4567").should_not be_nil
        (re =~ "abc-defg").should be_nil
      end
    end

    # =========================================================================
    # 2. Character class escapes INSIDE character classes [BUG 3]
    #    Currently \d, \w, \s are NOT converted inside [...], leaving
    #    PCRE2's Unicode-aware versions active. ECMA-262 requires ASCII-only.
    # =========================================================================
    describe "character class escapes inside [...]" do
      it "converts \\d inside [...] to ASCII-only (must NOT match Unicode digits)" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\d]")
        re = Regex.new(result)
        # Must match ASCII digits
        (re =~ "5").should_not be_nil
        (re =~ "0").should_not be_nil
        # Must NOT match Unicode digits (Arabic-Indic U+0660)
        (re =~ "\u0660").should be_nil
      end

      it "converts \\w inside [...] to ASCII-only (must NOT match Unicode letters)" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\w]")
        re = Regex.new(result)
        (re =~ "a").should_not be_nil
        (re =~ "Z").should_not be_nil
        (re =~ "_").should_not be_nil
        (re =~ "5").should_not be_nil
        # Must NOT match Unicode word characters
        (re =~ "é").should be_nil
        (re =~ "中").should be_nil
      end

      it "converts \\s inside [...] to match ECMA whitespace" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\s]")
        re = Regex.new(result)
        (re =~ " ").should_not be_nil
        (re =~ "\t").should_not be_nil
        (re =~ "\n").should_not be_nil
      end

      it "converts \\d mixed with other ranges inside [...]" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\da-f]")
        re = Regex.new(result)
        (re =~ "0").should_not be_nil
        (re =~ "9").should_not be_nil
        (re =~ "a").should_not be_nil
        (re =~ "f").should_not be_nil
        (re =~ "g").should be_nil
        # Must NOT match Unicode digits
        (re =~ "\u0660").should be_nil
      end

      it "converts \\w mixed with hyphen inside [...]" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\w-]")
        re = Regex.new(result)
        (re =~ "a").should_not be_nil
        (re =~ "-").should_not be_nil
        (re =~ "é").should be_nil
      end

      it "handles \\d in negated character class [^\\d]" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[^\\d]")
        re = Regex.new(result)
        (re =~ "5").should be_nil
        (re =~ "a").should_not be_nil
      end

      it "handles multiple escapes inside [...]" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\d\\w]")
        re = Regex.new(result)
        (re =~ "5").should_not be_nil
        (re =~ "a").should_not be_nil
        (re =~ "!").should be_nil
      end

      it "handles \\D inside [...] (compiles and matches non-digits)" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\D]")
        re = Regex.new(result)
        (re =~ "a").should_not be_nil
      end

      it "handles \\W inside [...] (compiles)" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\W]")
        re = Regex.new(result)
        (re =~ "!").should_not be_nil
      end
    end

    # =========================================================================
    # 3. Dollar anchor conversion
    # =========================================================================
    describe "dollar anchor conversion" do
      it "converts $ to \\z" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("$").should eq("\\z")
      end

      it "converts trailing $ in ^foo$" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("^foo$").should eq("^foo\\z")
      end

      it "does not convert escaped \\$" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\$").should eq("\\$")
      end

      it "does not convert $ inside character class" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("[$]").should eq("[$]")
      end

      it "converts multiple $ signs" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("a$b$").should eq("a\\zb\\z")
      end

      it "handles $ after group" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("(foo)$").should eq("(foo)\\z")
      end

      it "\\z does NOT match before trailing newline (unlike $)" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("^hello$")
        re = Regex.new(result)
        (re =~ "hello").should_not be_nil
        (re =~ "hello\n").should be_nil
      end
    end

    # =========================================================================
    # 4. Unicode escape conversion [BUG 1 & BUG 2]
    #    BUG 1: \uXXXX produces \u{XXXX} which PCRE2 rejects (\u not supported)
    #    BUG 2: Greedy regex captures >4 hex digits for unbraced \uXXXX form
    # =========================================================================
    describe "unicode escape conversion" do
      it "converts \\u0041 to compilable PCRE2 pattern matching 'A'" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u0041")
        # Must compile — BUG 1: currently produces \u0041 which PCRE2 rejects
        re = Regex.new(result)
        (re =~ "A").should_not be_nil
        (re =~ "B").should be_nil
      end

      it "converts \\u00e9 to compilable pattern matching 'é'" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u00e9")
        re = Regex.new(result)
        (re =~ "é").should_not be_nil
        (re =~ "e").should be_nil
      end

      it "converts \\u0020 to match space" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u0020")
        re = Regex.new(result)
        (re =~ " ").should_not be_nil
      end

      it "converts \\u{1F600} (> 0xFFFF) to literal emoji" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u{1F600}")
        result.should eq("😀")
      end

      it "converts \\u{0041} braced form to compilable pattern matching 'A'" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u{0041}")
        re = Regex.new(result)
        (re =~ "A").should_not be_nil
      end

      it "converts \\u{41} short braced form to compilable pattern matching 'A'" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u{41}")
        re = Regex.new(result)
        (re =~ "A").should_not be_nil
      end

      it "handles \\u00410 as \\u0041 + literal '0' (BUG 2: greedy capture)" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u00410")
        # Must compile
        re = Regex.new(result)
        # Should match "A0" — \u0041 is 'A', then literal '0'
        (re =~ "A0").should_not be_nil
      end

      it "handles multiple unicode escapes" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u0041\\u0042")
        re = Regex.new(result)
        (re =~ "AB").should_not be_nil
      end

      it "handles unicode escape mixed with literals" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("x\\u0041y")
        re = Regex.new(result)
        (re =~ "xAy").should_not be_nil
      end

      it "handles \\u with uppercase hex digits" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u00FF")
        re = Regex.new(result)
        (re =~ "ÿ").should_not be_nil
      end

      it "handles unicode escape inside character class range" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\u0041-\\u005A]")
        re = Regex.new(result)
        (re =~ "A").should_not be_nil
        (re =~ "Z").should_not be_nil
        (re =~ "a").should be_nil
      end

      it "handles \\u{10FFFF} max codepoint (> 0xFFFF becomes literal)" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\u{10FFFF}")
        # > 0xFFFF so should become literal char
        re = Regex.new(result)
      end
    end

    # =========================================================================
    # 5. Control escape normalization
    # =========================================================================
    describe "control escape normalization" do
      it "normalizes \\ca to \\cA" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\ca").should eq("\\cA")
      end

      it "normalizes \\cz to \\cZ" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\cz").should eq("\\cZ")
      end

      it "keeps \\cA as \\cA" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\cA").should eq("\\cA")
      end

      it "normalizes mixed case control escapes" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\cX\\cy\\cZ").should eq("\\cX\\cY\\cZ")
      end

      it "compiles and matches control character" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\cA")
        re = Regex.new(result)
        # \cA is SOH (U+0001)
        (re =~ "\u0001").should_not be_nil
      end
    end

    # =========================================================================
    # 6. Unicode property conversion
    # =========================================================================
    describe "unicode property conversion" do
      it "converts \\p{Letter} to \\p{L}" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{Letter}").should eq("\\p{L}")
      end

      it "converts \\p{Number} to \\p{N}" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{Number}").should eq("\\p{N}")
      end

      it "converts \\p{Digit} to \\p{Nd}" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{Digit}").should eq("\\p{Nd}")
      end

      it "converts \\p{Uppercase_Letter} to \\p{Lu}" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{Uppercase_Letter}").should eq("\\p{Lu}")
      end

      it "converts \\p{Lowercase_Letter} to \\p{Ll}" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{Lowercase_Letter}").should eq("\\p{Ll}")
      end

      it "converts \\P{Letter} to \\P{L} (negated)" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\P{Letter}").should eq("\\P{L}")
      end

      it "keeps \\p{L} (already short form)" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{L}").should eq("\\p{L}")
      end

      it "keeps script names like \\p{Latin}" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{Latin}").should eq("\\p{Latin}")
      end

      it "handles case-insensitive property names" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{LETTER}").should eq("\\p{L}")
      end

      it "handles dash normalization in property names" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{Uppercase-Letter}").should eq("\\p{Lu}")
      end

      it "converts all general category long names" do
        {
          "Letter"                 => "L",
          "Cased_Letter"           => "LC",
          "Uppercase_Letter"       => "Lu",
          "Lowercase_Letter"       => "Ll",
          "Titlecase_Letter"       => "Lt",
          "Modifier_Letter"        => "Lm",
          "Other_Letter"           => "Lo",
          "Mark"                   => "M",
          "Nonspacing_Mark"        => "Mn",
          "Spacing_Combining_Mark" => "Mc",
          "Enclosing_Mark"         => "Me",
          "Number"                 => "N",
          "Decimal_Number"         => "Nd",
          "Letter_Number"          => "Nl",
          "Other_Number"           => "No",
          "Punctuation"            => "P",
          "Connector_Punctuation"  => "Pc",
          "Dash_Punctuation"       => "Pd",
          "Open_Punctuation"       => "Ps",
          "Close_Punctuation"      => "Pe",
          "Initial_Punctuation"    => "Pi",
          "Final_Punctuation"      => "Pf",
          "Other_Punctuation"      => "Po",
          "Symbol"                 => "S",
          "Math_Symbol"            => "Sm",
          "Currency_Symbol"        => "Sc",
          "Modifier_Symbol"        => "Sk",
          "Other_Symbol"           => "So",
          "Separator"              => "Z",
          "Space_Separator"        => "Zs",
          "Line_Separator"         => "Zl",
          "Paragraph_Separator"    => "Zp",
          "Other"                  => "C",
          "Control"                => "Cc",
          "Format"                 => "Cf",
          "Surrogate"              => "Cs",
          "Private_Use"            => "Co",
          "Unassigned"             => "Cn",
        }.each do |long_name, short_name|
          result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{#{long_name}}")
          result.should eq("\\p{#{short_name}}")
        end
      end

      it "compiles converted property patterns and matches" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{Letter}")
        re = Regex.new(result)
        (re =~ "a").should_not be_nil
        (re =~ "1").should be_nil
      end

      it "converts binary properties" do
        {
          "ASCII"           => "ASCII",
          "Alphabetic"      => "Alphabetic",
          "White_Space"     => "White_Space",
          "Hex_Digit"       => "Hex_Digit",
          "ASCII_Hex_Digit" => "ASCII_Hex_Digit",
          "Lowercase"       => "Lowercase",
          "Uppercase"       => "Uppercase",
        }.each do |name, expected|
          result = JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{#{name}}")
          result.should eq("\\p{#{expected}}")
        end
      end
    end

    # =========================================================================
    # 7. Invalid escape detection
    # =========================================================================
    describe "invalid escape detection" do
      # Invalid ECMA-262 escapes outside character classes
      %w[a e g h i j l m o q y z].each do |c|
        it "raises InvalidEcmaRegexp for \\#{c} outside char class" do
          expect_raises(JsonSchemer::InvalidEcmaRegexp) do
            JsonSchemer::EcmaRegexp.crystal_equivalent("\\#{c}")
          end
        end
      end

      # Inside character classes, these are allowed as identity escapes
      %w[a e g h].each do |c|
        it "allows \\#{c} inside character class" do
          result = JsonSchemer::EcmaRegexp.crystal_equivalent("[\\#{c}]")
          result.should eq("[\\#{c}]")
        end
      end

      # Valid ECMA-262 escapes should NOT raise
      it "does not raise for \\b and \\B (word boundary)" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\b")
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\B")
      end

      it "does not raise for control escapes \\n \\r \\t \\f \\v" do
        %w[n r t f v].each do |c|
          JsonSchemer::EcmaRegexp.crystal_equivalent("\\#{c}")
        end
      end

      it "does not raise for \\0" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\0")
      end

      it "does not raise for backreferences \\1 through \\9" do
        (1..9).each do |n|
          JsonSchemer::EcmaRegexp.crystal_equivalent("\\#{n}")
        end
      end

      it "does not raise for \\d \\D \\w \\W \\s \\S" do
        %w[d D w W s S].each do |c|
          JsonSchemer::EcmaRegexp.crystal_equivalent("\\#{c}")
        end
      end

      it "does not raise for \\x \\u \\c \\p \\P \\k" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\x41")
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\u0041")
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\cA")
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\p{L}")
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\P{L}")
      end
    end

    # =========================================================================
    # 8. Pass-through patterns
    # =========================================================================
    describe "pass-through patterns" do
      it "passes through simple literals" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("abc").should eq("abc")
      end

      it "passes through alternation" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("(foo|bar)").should eq("(foo|bar)")
      end

      it "passes through quantifiers" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("a*").should eq("a*")
        JsonSchemer::EcmaRegexp.crystal_equivalent("a+").should eq("a+")
        JsonSchemer::EcmaRegexp.crystal_equivalent("a?").should eq("a?")
        JsonSchemer::EcmaRegexp.crystal_equivalent("a{3}").should eq("a{3}")
        JsonSchemer::EcmaRegexp.crystal_equivalent("a{3,}").should eq("a{3,}")
        JsonSchemer::EcmaRegexp.crystal_equivalent("a{3,5}").should eq("a{3,5}")
      end

      it "passes through dot" do
        JsonSchemer::EcmaRegexp.crystal_equivalent(".").should eq(".")
      end

      it "passes through caret anchor" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("^abc").should eq("^abc")
      end

      it "passes through lookahead (?=...)" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("(?=foo)").should eq("(?=foo)")
      end

      it "passes through negative lookahead (?!...)" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("(?!foo)").should eq("(?!foo)")
      end

      it "passes through lookbehind (?<=...)" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("(?<=foo)").should eq("(?<=foo)")
      end

      it "passes through non-capturing group (?:...)" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("(?:foo)").should eq("(?:foo)")
      end

      it "passes through character class with ranges" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("[a-zA-Z0-9]").should eq("[a-zA-Z0-9]")
      end

      it "passes through escaped special characters" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\.\\*\\+\\?").should eq("\\.\\*\\+\\?")
      end

      it "passes through escaped brackets" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\[\\]").should eq("\\[\\]")
      end
    end

    # =========================================================================
    # 9. Edge cases
    # =========================================================================
    describe "edge cases" do
      it "handles empty pattern" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("").should eq("")
      end

      it "handles pattern with only ^" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("^").should eq("^")
      end

      it "handles named groups with \\w conversion" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("(?<name>\\w+)")
        result.should eq("(?<name>[A-Za-z0-9_]+)")
      end

      it "handles backreferences" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("(a)\\1").should eq("(a)\\1")
      end

      it "handles escaped backslash" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\\\").should eq("\\\\")
      end

      it "handles double escaped backslash" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("\\\\\\\\").should eq("\\\\\\\\")
      end

      it "handles trailing backslash" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("abc\\").should eq("abc\\")
      end

      it "handles hyphen in character class" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("[a-z]").should eq("[a-z]")
      end

      it "handles ^ inside character class (negation)" do
        JsonSchemer::EcmaRegexp.crystal_equivalent("[^abc]").should eq("[^abc]")
      end

      it "handles complex real-world email-like pattern" do
        pattern = "^[\\w.+-]+@[\\w.-]+\\.[a-zA-Z]{2,}$"
        result = JsonSchemer::EcmaRegexp.crystal_equivalent(pattern)
        re = Regex.new(result)
        (re =~ "user@example.com").should_not be_nil
        (re =~ "not-an-email").should be_nil
      end

      it "handles phone number pattern with \\d" do
        pattern = "^\\+?\\d{1,3}-\\d{3,14}$"
        result = JsonSchemer::EcmaRegexp.crystal_equivalent(pattern)
        re = Regex.new(result)
        (re =~ "+1-5551234567").should_not be_nil
      end

      it "handles hex color pattern" do
        pattern = "^#[\\da-fA-F]{6}$"
        result = JsonSchemer::EcmaRegexp.crystal_equivalent(pattern)
        re = Regex.new(result)
        (re =~ "#FF00aa").should_not be_nil
        (re =~ "#ZZZZZZ").should be_nil
        # Unicode digits must NOT match inside [\\d...]
        (re =~ "#\u0660\u0660\u0660\u0660\u0660\u0660").should be_nil
      end

      it "handles ISO date pattern" do
        pattern = "^\\d{4}-\\d{2}-\\d{2}$"
        result = JsonSchemer::EcmaRegexp.crystal_equivalent(pattern)
        re = Regex.new(result)
        (re =~ "2024-01-15").should_not be_nil
        (re =~ "abcd-ef-gh").should be_nil
      end
    end

    # =========================================================================
    # 10. Compilability verification
    #     Every converted pattern MUST compile with Regex.new()
    # =========================================================================
    describe "compilability verification" do
      patterns = [
        "\\d", "\\D", "\\w", "\\W", "\\s", "\\S",
        "^foo$",
        "\\p{Letter}", "\\P{Number}",
        "\\cA", "\\ca",
        "(a|b)", "(?:abc)", "(?=foo)", "(?!foo)", "(?<=bar)", "(?<!bar)",
        "a{1,3}",
        "[a-z]", "[^0-9]",
        "\\b\\w+\\b",
        "\\\\", "\\.", "\\*",
        "^[a-zA-Z_][a-zA-Z0-9_]*$",
        "\\d{4}-\\d{2}-\\d{2}",
        "\\p{L}\\p{N}",
        "\\p{Decimal_Number}",
        "[\\d]", "[\\w]", "[\\s]",
        "[\\da-f]", "[\\w-]",
        "[\\d\\w]",
        "[^\\d]",
        "\\u0041",
        "\\u00e9",
        "\\u{0041}",
        "\\u{1F600}",
        "\\u0041\\u0042",
        "\\u00410",
      ]

      patterns.each do |pattern|
        it "compiles: #{pattern}" do
          result = JsonSchemer::EcmaRegexp.crystal_equivalent(pattern)
          Regex.new(result)
        end
      end
    end

    # =========================================================================
    # 11. Matching behavior verification
    # =========================================================================
    describe "matching behavior" do
      it "\\d+ matches only ASCII digit strings" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("^\\d+$")
        re = Regex.new(result)
        (re =~ "0123456789").should_not be_nil
        (re =~ "abc").should be_nil
        (re =~ "٠١٢").should be_nil # Arabic-Indic digits
      end

      it "\\w+ matches only ASCII word character strings" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("^\\w+$")
        re = Regex.new(result)
        (re =~ "hello_WORLD_123").should_not be_nil
        (re =~ "héllo").should be_nil
        (re =~ "日本語").should be_nil
      end

      it "$ matches end of string only (not before trailing newline)" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("^hello$")
        re = Regex.new(result)
        (re =~ "hello").should_not be_nil
        (re =~ "hello\n").should be_nil
      end

      it "\\p{Letter} matches Unicode letters" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("^\\p{Letter}+$")
        re = Regex.new(result)
        (re =~ "hello").should_not be_nil
        (re =~ "héllo").should_not be_nil
        (re =~ "日本語").should_not be_nil
        (re =~ "123").should be_nil
      end

      it "combined conversions: digits then letters" do
        result = JsonSchemer::EcmaRegexp.crystal_equivalent("^\\d+\\p{Letter}+$")
        re = Regex.new(result)
        (re =~ "123abc").should_not be_nil
        (re =~ "abc123").should be_nil
      end

      it "[\\d] inside char class matches same as \\d outside" do
        outside = JsonSchemer::EcmaRegexp.crystal_equivalent("^\\d$")
        inside = JsonSchemer::EcmaRegexp.crystal_equivalent("^[\\d]$")
        re_out = Regex.new(outside)
        re_in = Regex.new(inside)
        # Both should match ASCII digits
        (re_out =~ "5").should_not be_nil
        (re_in =~ "5").should_not be_nil
        # Both should NOT match Unicode digits
        (re_out =~ "\u0660").should be_nil
        (re_in =~ "\u0660").should be_nil
      end
    end

    # =========================================================================
    # 12. Integration with schema validation
    # =========================================================================
    describe "integration with schema validation" do
      it "validates pattern with regexp_resolver ecma" do
        schema = JsonSchemer.schema(
          JSON.parse(%q({"type": "string", "pattern": "^\\d{3}-\\d{4}$"})).as_h,
          regexp_resolver: "ecma"
        )
        schema.valid?(JSON::Any.new("123-4567")).should be_true
        schema.valid?(JSON::Any.new("abc-defg")).should be_false
      end

      it "validates \\w pattern as ASCII-only with ecma resolver" do
        schema = JsonSchemer.schema(
          JSON.parse(%q({"type": "string", "pattern": "^\\w+$"})).as_h,
          regexp_resolver: "ecma"
        )
        schema.valid?(JSON::Any.new("hello_123")).should be_true
        # ECMA \w is ASCII-only: é should NOT match
        schema.valid?(JSON::Any.new("héllo")).should be_false
      end

      it "validates unicode property pattern with ecma resolver" do
        schema = JsonSchemer.schema(
          JSON.parse(%q({"type": "string", "pattern": "^\\p{Letter}+$"})).as_h,
          regexp_resolver: "ecma"
        )
        schema.valid?(JSON::Any.new("hello")).should be_true
        schema.valid?(JSON::Any.new("123")).should be_false
      end
    end
  end

  # ===========================================================================
  # .valid? method
  # ===========================================================================
  describe ".valid?" do
    it "returns true for valid simple patterns" do
      JsonSchemer::EcmaRegexp.valid?("^[a-z]+$").should be_true
      JsonSchemer::EcmaRegexp.valid?("\\d{3}").should be_true
      JsonSchemer::EcmaRegexp.valid?("(a|b)").should be_true
    end

    it "returns true for empty string" do
      JsonSchemer::EcmaRegexp.valid?("").should be_true
    end

    it "returns false for invalid ECMA escape sequences" do
      JsonSchemer::EcmaRegexp.valid?("\\a").should be_false
      JsonSchemer::EcmaRegexp.valid?("\\e").should be_false
      JsonSchemer::EcmaRegexp.valid?("\\l").should be_false
    end

    it "returns false for unmatched brackets" do
      JsonSchemer::EcmaRegexp.valid?("[abc").should be_false
    end

    it "returns false for unmatched parentheses" do
      JsonSchemer::EcmaRegexp.valid?("(abc").should be_false
    end

    it "returns true for patterns with all conversion types" do
      JsonSchemer::EcmaRegexp.valid?("^\\d+\\w*\\s?$").should be_true
      JsonSchemer::EcmaRegexp.valid?("\\p{Letter}").should be_true
      JsonSchemer::EcmaRegexp.valid?("\\cA").should be_true
    end
  end
end
