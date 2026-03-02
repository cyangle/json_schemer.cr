require "./spec_helper"

describe "Validation Edge Cases" do
  # ========================
  # Boolean Schemas
  # ========================
  describe "true schema (accepts everything)" do
    it "accepts string" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
    end

    it "accepts integer" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
    end

    it "accepts float" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON::Any.new(3.14)).should be_true
    end

    it "accepts boolean true" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON::Any.new(true)).should be_true
    end

    it "accepts boolean false" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON::Any.new(false)).should be_true
    end

    it "accepts null" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON::Any.new(nil)).should be_true
    end

    it "accepts empty array" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON.parse("[]")).should be_true
    end

    it "accepts non-empty array" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_true
    end

    it "accepts empty object" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON.parse("{}")).should be_true
    end

    it "accepts non-empty object" do
      schema = JsonSchemer.schema(JSON.parse(%q({})).as_h)
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
    end
  end

  describe "false schema (rejects everything)" do
    it "rejects string" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_false
    end

    it "rejects integer" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON::Any.new(42_i64)).should be_false
    end

    it "rejects float" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON::Any.new(3.14)).should be_false
    end

    it "rejects boolean true" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON::Any.new(true)).should be_false
    end

    it "rejects boolean false" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON::Any.new(false)).should be_false
    end

    it "rejects null" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON::Any.new(nil)).should be_false
    end

    it "rejects empty array" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON.parse("[]")).should be_false
    end

    it "rejects non-empty array" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_false
    end

    it "rejects empty object" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON.parse("{}")).should be_false
    end

    it "rejects non-empty object" do
      schema = JsonSchemer.schema(JSON.parse(%q({"not": {}})).as_h)
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_false
    end
  end

  # ========================
  # Enum Edge Cases
  # ========================
  describe "enum with mixed types" do
    it "validates enum with integers and strings" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": [1, "hello", 2, "world"]})).as_h)
      schema.valid?(JSON::Any.new(1_i64)).should be_true
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(2_i64)).should be_true
      schema.valid?(JSON::Any.new("world")).should be_true
      schema.valid?(JSON::Any.new(3_i64)).should be_false
      schema.valid?(JSON::Any.new("test")).should be_false
    end

    it "validates enum with null" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": [1, null, 2]})).as_h)
      schema.valid?(JSON::Any.new(1_i64)).should be_true
      schema.valid?(JSON::Any.new(nil)).should be_true
      schema.valid?(JSON::Any.new(2_i64)).should be_true
      schema.valid?(JSON::Any.new("null")).should be_false
    end

    it "validates enum with booleans" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": [true, false, 1]})).as_h)
      schema.valid?(JSON::Any.new(true)).should be_true
      schema.valid?(JSON::Any.new(false)).should be_true
      schema.valid?(JSON::Any.new(1_i64)).should be_true
      schema.valid?(JSON::Any.new(0_i64)).should be_false
    end

    it "validates enum with objects" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": [{"a": 1}, {"b": 2}]})).as_h)
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"b": 2}))).should be_true
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"c": 3}))).should be_false
    end

    it "validates enum with arrays" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": [[1, 2], [3, 4]]})).as_h)
      schema.valid?(JSON.parse(%q([1, 2]))).should be_true
      schema.valid?(JSON.parse(%q([3, 4]))).should be_true
      schema.valid?(JSON.parse(%q([1, 2, 3]))).should be_false
    end
  end

  describe "enum with duplicate values" do
    it "handles duplicate integers" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": [1, 1, 2, 2]})).as_h)
      schema.valid?(JSON::Any.new(1_i64)).should be_true
      schema.valid?(JSON::Any.new(2_i64)).should be_true
      schema.valid?(JSON::Any.new(3_i64)).should be_false
    end

    it "handles duplicate strings" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": ["a", "a", "b"]})).as_h)
      schema.valid?(JSON::Any.new("a")).should be_true
      schema.valid?(JSON::Any.new("b")).should be_true
      schema.valid?(JSON::Any.new("c")).should be_false
    end
  end

  describe "empty array enum" do
    it "nothing should be valid (empty enum array)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"enum": []})).as_h)
      schema.valid?(JSON::Any.new("anything")).should be_false
      schema.valid?(JSON::Any.new(1_i64)).should be_false
      schema.valid?(JSON::Any.new(nil)).should be_false
      schema.valid?(JSON.parse("[]")).should be_false
      schema.valid?(JSON.parse("{}")).should be_false
    end
  end

  # ========================
  # UniqueItems Edge Cases
  # ========================
  describe "uniqueItems with duplicate integers" do
    it "detects duplicate integers [1, 1]" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse("[1, 1]")).should be_false
    end

    it "allows unique integers [1, 2, 3]" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_true
    end
  end

  describe "uniqueItems with integer vs float" do
    it "treats 1 and 1.0 as equal (same numeric value, duplicates)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse("[1, 1.0]")).should be_false
    end

    it "treats 0 and 0.0 as equal (same numeric value, duplicates)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse("[0, 0.0]")).should be_false
    end

    it "treats true and 1 as different (bool vs int)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse("[true, 1]")).should be_true
    end

    it "treats false and 0 as different (bool vs int)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse("[false, 0]")).should be_true
    end
  end

  describe "uniqueItems with nested arrays/objects" do
    it "detects duplicate nested arrays" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse(%q([[1, 2], [1, 2]]))).should be_false
    end

    it "allows unique nested arrays" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse(%q([[1, 2], [3, 4]]))).should be_true
    end

    it "detects duplicate objects" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse(%q([{"a": 1}, {"a": 1}]))).should be_false
    end

    it "allows unique objects" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse(%q([{"a": 1}, {"a": 2}]))).should be_true
    end

    it "handles mixed types in array" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": true})).as_h)
      schema.valid?(JSON.parse(%q([1, "1", true, null, [1]]))).should be_true
    end
  end

  describe "uniqueItems false allows duplicates" do
    it "allows duplicate items when uniqueItems: false" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "uniqueItems": false})).as_h)
      schema.valid?(JSON.parse("[1, 1, 1]")).should be_true
      schema.valid?(JSON.parse(%q(["a", "a", "b", "b"]))).should be_true
    end
  end

  # ========================
  # MultipleOf Edge Cases
  # ========================
  describe "multipleOf with floating point precision" do
    it "handles 0.3 with multipleOf: 0.1" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "multipleOf": 0.1})).as_h)
      schema.valid?(JSON::Any.new(0.3)).should be_true
      schema.valid?(JSON::Any.new(0.6)).should be_true
    end

    it "handles 0.33 with multipleOf: 0.01" do
      schema = JsonSchemer.schema(JSON.parse(%q({"multipleOf": 0.01})).as_h)
      schema.valid?(JSON::Any.new(0.33)).should be_true
      schema.valid?(JSON::Any.new(0.99)).should be_true
    end
  end

  describe "multipleOf with integer values" do
    it "accepts multiples of 1" do
      schema = JsonSchemer.schema(JSON.parse(%q({"multipleOf": 1})).as_h)
      schema.valid?(JSON::Any.new(0_i64)).should be_true
      schema.valid?(JSON::Any.new(1_i64)).should be_true
      schema.valid?(JSON::Any.new(-5_i64)).should be_true
    end

    it "accepts multiples of 5" do
      schema = JsonSchemer.schema(JSON.parse(%q({"multipleOf": 5})).as_h)
      schema.valid?(JSON::Any.new(0_i64)).should be_true
      schema.valid?(JSON::Any.new(5_i64)).should be_true
      schema.valid?(JSON::Any.new(10_i64)).should be_true
      schema.valid?(JSON::Any.new(7_i64)).should be_false
    end

    it "rejects non-multiples" do
      schema = JsonSchemer.schema(JSON.parse(%q({"multipleOf": 3})).as_h)
      schema.valid?(JSON::Any.new(1_i64)).should be_false
      schema.valid?(JSON::Any.new(2_i64)).should be_false
      schema.valid?(JSON::Any.new(4_i64)).should be_false
    end
  end

  describe "multipleOf with decimal values" do
    it "accepts 7.5 with multipleOf: 2.5" do
      schema = JsonSchemer.schema(JSON.parse(%q({"multipleOf": 2.5})).as_h)
      schema.valid?(JSON::Any.new(7.5)).should be_true
      schema.valid?(JSON::Any.new(2.5)).should be_true
      schema.valid?(JSON::Any.new(0.0)).should be_true
    end

    it "rejects 7.6 with multipleOf: 2.5" do
      schema = JsonSchemer.schema(JSON.parse(%q({"multipleOf": 2.5})).as_h)
      schema.valid?(JSON::Any.new(7.6)).should be_false
    end
  end

  describe "multipleOf with large numbers" do
    it "handles large number multiples" do
      schema = JsonSchemer.schema(JSON.parse(%q({"multipleOf": 1000000})).as_h)
      schema.valid?(JSON::Any.new(1000000_i64)).should be_true
      schema.valid?(JSON::Any.new(2000000_i64)).should be_true
      schema.valid?(JSON::Any.new(999999_i64)).should be_false
    end
  end

  # ========================
  # String Length with Unicode
  # ========================
  describe "string length with multi-byte UTF-8" do
    it "counts German umlauts as 1 char each" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "minLength": 1, "maxLength": 5})).as_h)
      # café = 4 chars (c-a-f-é), é is 2 bytes
      schema.valid?(JSON::Any.new("café")).should be_true
      # German: Schön = 5 chars (S-c-h-ö-n), ö is 2 bytes
      schema.valid?(JSON::Any.new("Schön")).should be_true
      # 6 chars would fail maxLength
      schema.valid?(JSON::Any.new("Schöne")).should be_false
    end

    it "counts emoji as 1 char each (but multiple bytes)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "minLength": 1, "maxLength": 5})).as_h)
      # 😀 = 1 char, 4 bytes
      schema.valid?(JSON::Any.new("😀")).should be_true
      # 😀🚀 = 2 chars
      schema.valid?(JSON::Any.new("😀🚀")).should be_true
      # 5 emoji should pass
      schema.valid?(JSON::Any.new("😀🚀🔥🌟✨")).should be_true
      # 6 emoji should fail
      schema.valid?(JSON::Any.new("😀🚀🔥🌟✨💫")).should be_false
    end

    it "handles Chinese characters" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "minLength": 2, "maxLength": 4})).as_h)
      # 你好 = 2 chars
      schema.valid?(JSON::Any.new("你好")).should be_true
      # 中国 = 2 chars
      schema.valid?(JSON::Any.new("中国")).should be_true
      # 1234 = 4 chars
      schema.valid?(JSON::Any.new("1234")).should be_true
      # 你好啊 = 3 chars, still within maxLength: 4
      schema.valid?(JSON::Any.new("你好啊")).should be_true
      # 5 chars should fail
      schema.valid?(JSON::Any.new("你好啊世界")).should be_false
    end

    it "handles Japanese characters" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "minLength": 1, "maxLength": 3})).as_h)
      # あいう = 3 chars
      schema.valid?(JSON::Any.new("あいう")).should be_true
      #  abc = 4 chars (3 hiragana + 1 space)
      schema.valid?(JSON::Any.new("あ い")).should be_true
      # 4 chars should fail
      schema.valid?(JSON::Any.new("あいうえ")).should be_false
    end

    it "handles mixed emoji and text" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "minLength": 3, "maxLength": 7})).as_h)
      # Hello 😀 = 7 chars (H-e-l-l-o-space-😀)
      schema.valid?(JSON::Any.new("Hello 😀")).should be_true
      # Hi! 🌟 = 5 chars
      schema.valid?(JSON::Any.new("Hi! 🌟")).should be_true
      # A😀B🚀C🔥 = 6 chars (3 letters + 3 emoji)
      schema.valid?(JSON::Any.new("A😀B🚀C🔥")).should be_true
      # 8 chars should fail
      schema.valid?(JSON::Any.new("Hello 😀!")).should be_false
    end
  end

  # ========================
  # Numeric Limits Precision
  # ========================
  describe "minimum with -0.0" do
    it "treats -0.0 as equal to 0 (passes minimum: 0)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "minimum": 0})).as_h)
      schema.valid?(JSON::Any.new(0.0)).should be_true
      schema.valid?(JSON::Any.new(-0.0)).should be_true
    end

    it "rejects negative numbers with minimum: 0" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "minimum": 0})).as_h)
      schema.valid?(JSON::Any.new(-0.001)).should be_false
      schema.valid?(JSON::Any.new(-1.0)).should be_false
    end
  end

  describe "exclusiveMinimum with very small positive numbers" do
    it "accepts 0.001 with exclusiveMinimum: 0" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "exclusiveMinimum": 0})).as_h)
      schema.valid?(JSON::Any.new(0.001)).should be_true
      schema.valid?(JSON::Any.new(0.000001)).should be_true
    end

    it "rejects 0 with exclusiveMinimum: 0" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "exclusiveMinimum": 0})).as_h)
      schema.valid?(JSON::Any.new(0.0)).should be_false
    end

    it "rejects negative with exclusiveMinimum: 0" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "exclusiveMinimum": 0})).as_h)
      schema.valid?(JSON::Any.new(-0.001)).should be_false
    end
  end

  describe "maximum at 2^53 boundary (9007199254740992)" do
    it "accepts values at 2^53 boundary" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "maximum": 9007199254740992})).as_h)
      schema.valid?(JSON::Any.new(9007199254740992.0)).should be_true
      schema.valid?(JSON::Any.new(9007199254740991.0)).should be_true
    end

    it "float precision: 9007199254740993.0 equals 9007199254740992.0 in Float64" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "maximum": 9007199254740992})).as_h)
      # Due to Float64 precision, 9007199254740993.0 == 9007199254740992.0
      schema.valid?(JSON::Any.new(9007199254740993.0)).should be_true
    end
  end

  describe "integer vs float comparisons at boundaries" do
    it "treats integer 5 same as float 5.0 for minimum" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "minimum": 5})).as_h)
      schema.valid?(JSON::Any.new(5_i64)).should be_true
      schema.valid?(JSON::Any.new(5.0)).should be_true
    end

    it "treats integer 10 same as float 10.0 for maximum" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "number", "maximum": 10})).as_h)
      schema.valid?(JSON::Any.new(10_i64)).should be_true
      schema.valid?(JSON::Any.new(10.0)).should be_true
    end
  end

  # ========================
  # Const Keyword Edge Cases
  # ========================
  describe "const with null" do
    it "validates only null" do
      schema = JsonSchemer.schema(JSON.parse(%q({"const": null})).as_h)
      schema.valid?(JSON::Any.new(nil)).should be_true
      schema.valid?(JSON::Any.new("null")).should be_false
      schema.valid?(JSON::Any.new(0)).should be_false
    end
  end

  describe "const with integer" do
    it "validates only exact integer" do
      schema = JsonSchemer.schema(JSON.parse(%q({"const": 42})).as_h)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      # JSON::Any considers 42 == 42.0 (same numeric value)
      schema.valid?(JSON::Any.new(42.0)).should be_true
      schema.valid?(JSON::Any.new(43_i64)).should be_false
    end

    it "rejects different numeric values" do
      schema = JsonSchemer.schema(JSON.parse(%q({"const": 42})).as_h)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new(41_i64)).should be_false
      schema.valid?(JSON::Any.new(43_i64)).should be_false
    end
  end

  describe "const with string" do
    it "validates only exact string" do
      schema = JsonSchemer.schema(JSON.parse(%q({"const": "hello"})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("Hello")).should be_false
      schema.valid?(JSON::Any.new("hello ")).should be_false
    end
  end

  describe "const with array" do
    it "validates only exact array" do
      schema = JsonSchemer.schema(JSON.parse(%q({"const": [1, 2, 3]})).as_h)
      schema.valid?(JSON.parse(%q([1, 2, 3]))).should be_true
      schema.valid?(JSON.parse(%q([1, 2, 3, 4]))).should be_false
      schema.valid?(JSON.parse(%q([1, 2]))).should be_false
      schema.valid?(JSON.parse(%q([3, 2, 1]))).should be_false
    end
  end

  describe "const with object" do
    it "validates only exact object" do
      schema = JsonSchemer.schema(JSON.parse(%q({"const": {"a": 1}})).as_h)
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2}))).should be_false
      schema.valid?(JSON.parse(%q({"a": 2}))).should be_false
      schema.valid?(JSON.parse(%q({"b": 1}))).should be_false
    end
  end

  # ========================
  # Pattern Keyword Edge Cases
  # ========================
  describe "basic pattern matching" do
    it "validates simple regex pattern" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "pattern": "^[a-z]+$"})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("Hello")).should be_false
      schema.valid?(JSON::Any.new("hello123")).should be_false
    end

    it "validates pattern with digits" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "pattern": "^\\d+$"})).as_h)
      schema.valid?(JSON::Any.new("123")).should be_true
      schema.valid?(JSON::Any.new("12a3")).should be_false
    end

    it "validates pattern with special regex chars" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"})).as_h)
      schema.valid?(JSON::Any.new("test@example.com")).should be_true
      schema.valid?(JSON::Any.new("invalid")).should be_false
    end
  end

  describe "empty pattern (matches everything)" do
    it "empty pattern matches any string" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "pattern": ""})).as_h)
      schema.valid?(JSON::Any.new("")).should be_true
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("123")).should be_true
      schema.valid?(JSON::Any.new("!@#$%")).should be_true
    end
  end

  describe "pattern special cases" do
    it "matches start/end anchors" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "pattern": "^start"})).as_h)
      schema.valid?(JSON::Any.new("start here")).should be_true
      schema.valid?(JSON::Any.new("ends with start")).should be_false
    end

    it "matches word boundaries" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "pattern": "\\btest\\b"})).as_h)
      schema.valid?(JSON::Any.new("test word")).should be_true
      schema.valid?(JSON::Any.new("testing")).should be_false
    end
  end

  describe "pattern with non-string instance" do
    it "skips pattern validation for non-strings" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "pattern": "^[a-z]+$"})).as_h)
      # Note: When type is "string", non-strings would fail type first
      # But with type: any, pattern only applies to strings
      any_type_schema = JsonSchemer.schema(JSON.parse(%q({"pattern": "^[a-z]+$"})).as_h)
      any_type_schema.valid?(JSON::Any.new(123)).should be_true
      any_type_schema.valid?(JSON::Any.new(nil)).should be_true
    end
  end

  # ========================
  # Type Array Edge Cases
  # ========================
  describe "type array with nullable string" do
    it "accepts string or null" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": ["string", "null"]})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(nil)).should be_true
      schema.valid?(JSON::Any.new(123)).should be_false
      schema.valid?(JSON::Any.new(true)).should be_false
    end
  end

  describe "type array with integer and string" do
    it "accepts integer or string, not number" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": ["integer", "string"]})).as_h)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42.5)).should be_false
    end
  end

  describe "type array with boolean and null" do
    it "accepts boolean or null, not string 'true'" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": ["boolean", "null"]})).as_h)
      schema.valid?(JSON::Any.new(true)).should be_true
      schema.valid?(JSON::Any.new(false)).should be_true
      schema.valid?(JSON::Any.new(nil)).should be_true
      schema.valid?(JSON::Any.new("true")).should be_false
    end
  end

  describe "empty type array" do
    it "matches nothing (no type satisfies empty array)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": []})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_false
      schema.valid?(JSON::Any.new(123)).should be_false
      schema.valid?(JSON::Any.new(nil)).should be_false
    end
  end

  # ========================
  # Required Keyword Edge Cases
  # ========================
  describe "empty required array" do
    it "no keys required" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "object", "required": []})).as_h)
      schema.valid?(JSON.parse("{}")).should be_true
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2, "c": 3}))).should be_true
    end
  end

  describe "required on non-object" do
    it "passes for non-objects (type mismatch = no validation)" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "required": ["name"]})).as_h)
      # Required only applies to objects, so strings pass
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("")).should be_true
    end
  end

  describe "required with additionalProperties" do
    it "additionalProperties: false rejects all props when no properties defined" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "required": ["a"],
        "additionalProperties": false
      })).as_h)
      # Without 'properties' key, ALL properties are 'additional' and rejected
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_false
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2}))).should be_false
    end

    it "additionalProperties: false with properties allows defined props" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "type": "object",
        "required": ["a"],
        "properties": {"a": {"type": "integer"}},
        "additionalProperties": false
      })).as_h)
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2}))).should be_false
    end
  end

  # ========================
  # MinProperties / MaxProperties Edge Cases
  # ========================
  describe "minProperties with 0" do
    it "any object passes with minProperties: 0" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "object", "minProperties": 0})).as_h)
      schema.valid?(JSON.parse("{}")).should be_true
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_true
    end
  end

  describe "maxProperties with 0" do
    it "only empty object passes with maxProperties: 0" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "object", "maxProperties": 0})).as_h)
      schema.valid?(JSON.parse("{}")).should be_true
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_false
    end
  end

  describe "minProperties validation" do
    it "object with 1 prop fails minProperties: 2" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "object", "minProperties": 2})).as_h)
      schema.valid?(JSON.parse("{}")).should be_false
      schema.valid?(JSON.parse(%q({"a": 1}))).should be_false
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2}))).should be_true
      schema.valid?(JSON.parse(%q({"a": 1, "b": 2, "c": 3}))).should be_true
    end
  end

  describe "minProperties/maxProperties on non-objects" do
    it "passes for non-objects" do
      min_schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "minProperties": 2})).as_h)
      max_schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "maxProperties": 0})).as_h)
      # These keywords only apply to objects; strings pass without validation
      min_schema.valid?(JSON::Any.new("hello")).should be_true
      max_schema.valid?(JSON::Any.new("hello")).should be_true
    end
  end

  # ========================
  # MinItems / MaxItems Edge Cases
  # ========================
  describe "minItems with 0" do
    it "any array passes with minItems: 0" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "minItems": 0})).as_h)
      schema.valid?(JSON.parse("[]")).should be_true
      schema.valid?(JSON.parse("[1]")).should be_true
    end
  end

  describe "maxItems with 0" do
    it "only empty array passes with maxItems: 0" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "maxItems": 0})).as_h)
      schema.valid?(JSON.parse("[]")).should be_true
      schema.valid?(JSON.parse("[1]")).should be_false
    end
  end

  describe "minItems validation" do
    it "array with 1 item fails minItems: 2" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "array", "minItems": 2})).as_h)
      schema.valid?(JSON.parse("[]")).should be_false
      schema.valid?(JSON.parse("[1]")).should be_false
      schema.valid?(JSON.parse("[1, 2]")).should be_true
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_true
    end
  end

  describe "minItems/maxItems on non-arrays" do
    it "passes for non-arrays" do
      min_schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "minItems": 2})).as_h)
      max_schema = JsonSchemer.schema(JSON.parse(%q({"type": "string", "maxItems": 0})).as_h)
      min_schema.valid?(JSON::Any.new("hello")).should be_true
      max_schema.valid?(JSON::Any.new("hello")).should be_true
    end
  end

  # ========================
  # Applicator Edge Cases
  # ========================
  describe "allOf - both must match" do
    it "validates when both schemas match" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "allOf": [
          {"type": "string"},
          {"minLength": 3}
        ]
      })).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new("hi")).should be_false # fails minLength
      schema.valid?(JSON::Any.new(123)).should be_false  # fails type
    end

    it "validates allOf with three schemas" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "allOf": [
          {"type": "integer"},
          {"minimum": 0},
          {"maximum": 100}
        ]
      })).as_h)
      schema.valid?(JSON::Any.new(50_i64)).should be_true
      schema.valid?(JSON::Any.new(-1_i64)).should be_false
      schema.valid?(JSON::Any.new(101_i64)).should be_false
    end
  end

  describe "anyOf - one must match" do
    it "validates when one schema matches" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "anyOf": [
          {"type": "string"},
          {"type": "integer"}
        ]
      })).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new(true)).should be_false
    end

    it "validates when multiple schemas match" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "anyOf": [
          {"type": "string"},
          {"minLength": 3}
        ]
      })).as_h)
      # "hello" matches both, but anyOf only needs one
      schema.valid?(JSON::Any.new("hello")).should be_true
    end
  end

  describe "oneOf - exactly one must match" do
    it "validates when exactly one schema matches" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "oneOf": [
          {"type": "string", "minLength": 5},
          {"type": "string", "maxLength": 3}
        ]
      })).as_h)
      # "hello" matches minLength: 5 (length 5) but not maxLength: 3
      schema.valid?(JSON::Any.new("hello")).should be_true
      # "hi" matches maxLength: 3 (length 2) but not minLength: 5
      schema.valid?(JSON::Any.new("hi")).should be_true
      # "test" matches neither (length 4)
      schema.valid?(JSON::Any.new("test")).should be_false
    end

    it "rejects when multiple schemas match" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "oneOf": [
          {"type": "string"},
          {"minLength": 3}
        ]
      })).as_h)
      # "hello" matches both (type string AND minLength 3)
      schema.valid?(JSON::Any.new("hello")).should be_false
    end

    it "rejects when no schemas match" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "oneOf": [
          {"type": "integer", "minimum": 10},
          {"type": "integer", "maximum": 5}
        ]
      })).as_h)
      schema.valid?(JSON::Any.new(7_i64)).should be_false
    end
  end

  describe "not - inverse" do
    it "validates when NOT matching schema" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "not": {"type": "string"}
      })).as_h)
      schema.valid?(JSON::Any.new(42_i64)).should be_true
      schema.valid?(JSON::Any.new(true)).should be_true
      schema.valid?(JSON::Any.new(nil)).should be_true
      schema.valid?(JSON::Any.new("hello")).should be_false
    end

    it "validates not with complex schema" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "not": {
          "type": "object",
          "required": ["id"]
        }
      })).as_h)
      schema.valid?(JSON::Any.new(42)).should be_true
      schema.valid?(JSON.parse("{}")).should be_true
      schema.valid?(JSON.parse(%q({"id": 1}))).should be_false
    end
  end

  describe "if/then/else conditional" do
    it "validates if/then when if matches" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "if": {"type": "string"},
        "then": {"minLength": 3},
        "else": {"minimum": 0}
      })).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true # if matched, then passed
      schema.valid?(JSON::Any.new("hi")).should be_false   # if matched, then failed (minLength)
      schema.valid?(JSON::Any.new(42_i64)).should be_true  # if didn't match, else passed
    end

    it "validates if/then/else with number condition" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "if": {"type": "number", "minimum": 0},
        "then": {"maximum": 100},
        "else": {"minimum": -100}
      })).as_h)
      schema.valid?(JSON::Any.new(50_i64)).should be_true    # positive, max 100 passed
      schema.valid?(JSON::Any.new(150_i64)).should be_false  # positive, max 100 failed
      schema.valid?(JSON::Any.new(-50_i64)).should be_true   # negative, else passed
      schema.valid?(JSON::Any.new(-150_i64)).should be_false # negative, else failed
    end

    it "validates if/then without else" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "if": {"type": "string"},
        "then": {"minLength": 5}
      })).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true # if matched, then passed
      schema.valid?(JSON::Any.new("hi")).should be_false   # if matched, then failed
      schema.valid?(JSON::Any.new(42_i64)).should be_true  # if didn't match, passes (no else)
    end
  end

  describe "if/then with nested arrays" do
    it "handles if/then with array constraints" do
      schema = JsonSchemer.schema(JSON.parse(%q({
        "if": {"type": "array", "minItems": 3},
        "then": {"uniqueItems": true},
        "else": {"maxItems": 5}
      })).as_h)
      schema.valid?(JSON.parse("[1, 2, 3]")).should be_true  # if matched (3 items >= 3), then: uniqueItems passed
      schema.valid?(JSON.parse("[1, 2, 2]")).should be_false # if matched (3 items >= 3), then: uniqueItems failed
      schema.valid?(JSON.parse("[1, 2]")).should be_true     # if not matched (2 < 3), else: maxItems 5 passed
      # 6 items >= 3 so if matches, then branch: uniqueItems true, all unique -> valid
      schema.valid?(JSON.parse("[1, 2, 3, 4, 5, 6]")).should be_true
      # 6 items >= 3 so if matches, then branch: uniqueItems true, has dup -> invalid
      schema.valid?(JSON.parse("[1, 2, 3, 4, 5, 5]")).should be_false
    end
  end
end
