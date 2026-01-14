require "./spec_helper"

# JSON Schema Test Suite integration tests
# These tests use the official JSON Schema Test Suite from:
# https://github.com/json-schema-org/JSON-Schema-Test-Suite
#
# The test suite is included as a git submodule at JSON-Schema-Test-Suite/

module JsonSchemaTestSuite
  # Path to the test suite
  TEST_SUITE_PATH = Path.new(__DIR__).parent / "JSON-Schema-Test-Suite"
  TESTS_PATH      = TEST_SUITE_PATH / "tests"
  REMOTES_PATH    = TEST_SUITE_PATH / "remotes"

  # Files to skip due to limitations
  SKIP_FILES = Set{
    # Contains integers too large for Crystal's JSON parser (Int64 overflow)
    "bignum.json",
    # References draft-2019-09 which is not implemented
    "cross-draft.json",
  }

  # Ref resolver that loads remote schemas from the filesystem
  # Remote refs like http://localhost:1234/foo.json -> remotes/foo.json
  REF_RESOLVER = JsonSchemer::CachedRefResolver.new do |uri|
    if uri.host == "localhost" && uri.port == 1234
      path = uri.path.not_nil!.lchop('/')
      full_path = REMOTES_PATH / path
      JsonSchemer::JSONHash.from_json(File.read(full_path))
    else
      # For meta-schema refs, let the default resolver handle them
      nil
    end
  end

  # Helper to create schema from JSON::Any value
  # Returns either a Bool (for boolean schemas) or JSONHash (for object schemas)
  def self.schema_value(value : JSON::Any) : JSON::Any | JsonSchemer::JSONHash | Bool
    case raw = value.raw
    when Hash
      result = JsonSchemer::JSONHash.new
      raw.each do |k, v|
        result[k.to_s] = v.as(JSON::Any)
      end
      result
    when Bool
      # Boolean schemas are valid in JSON Schema
      # true = accept everything, false = reject everything
      # The Schema class handles Bool directly
      raw
    else
      # For non-object, non-boolean schemas (shouldn't happen in valid test cases)
      JsonSchemer::JSONHash.new
    end
  end

  # Check if file should be skipped
  def self.skip_file?(filename : String) : Bool
    SKIP_FILES.includes?(filename)
  end
end

describe "JSON Schema Test Suite" do
  meta_schema = JsonSchemer.draft202012

  # Required tests for draft2020-12
  describe "draft2020-12" do
    describe "required" do
      {% for file in `ls #{__DIR__}/../JSON-Schema-Test-Suite/tests/draft2020-12/*.json 2>/dev/null || true`.lines %}
        {% if file.size > 0 %}
          {% file_path = file.strip %}
          {% file_name = file_path.split("/").last %}
          {% unless file_name == "" %}
            describe {{ file_name }} do
              file_path = Path.new({{ file_path }})
              file_name = {{ file_name }}

              if JsonSchemaTestSuite.skip_file?(file_name)
                pending "Skipped: #{file_name} (unsupported by Crystal JSON parser)"
              else
                content = File.read(file_path)
                test_cases = JSON.parse(content).as_a

                test_cases.each do |test_case|
                  description = test_case["description"].as_s
                  schema_value_raw = test_case["schema"]
                  tests = test_case["tests"].as_a

                  # Get proper schema value (Bool or JSONHash)
                  schema_val = JsonSchemaTestSuite.schema_value(schema_value_raw)

                  tests.each do |test|
                    test_description = test["description"].as_s
                    data = test["data"]
                    expected_valid = test["valid"].as_bool

                    it "#{description}: #{test_description}" do
                      schemer = JsonSchemer::Schema.new(
                        schema_val,
                        meta_schema: meta_schema,
                        format: false,
                        ref_resolver: JsonSchemaTestSuite::REF_RESOLVER.to_proc,
                        regexp_resolver: "ecma"
                      )

                      actual_valid = schemer.valid?(data)
                      actual_valid.should eq(expected_valid),
                        "Expected valid=#{expected_valid}, got valid=#{actual_valid}\n" \
                        "  Schema: #{schema_value_raw.to_pretty_json}\n" \
                        "  Data: #{data.to_pretty_json}"
                    end
                  end
                end
              end
            end
          {% end %}
        {% end %}
      {% end %}
    end

    # Optional tests (excluding format/ subdirectory)
    describe "optional" do
      {% for file in `ls #{__DIR__}/../JSON-Schema-Test-Suite/tests/draft2020-12/optional/*.json 2>/dev/null || true`.lines %}
        {% if file.size > 0 %}
          {% file_path = file.strip %}
          {% file_name = file_path.split("/").last %}
          {% unless file_name == "" %}
            describe {{ file_name }} do
              file_path = Path.new({{ file_path }})
              file_name = {{ file_name }}

              if JsonSchemaTestSuite.skip_file?(file_name)
                pending "Skipped: #{file_name} (unsupported by Crystal JSON parser)"
              else
                content = File.read(file_path)
                test_cases = JSON.parse(content).as_a

                test_cases.each do |test_case|
                  description = test_case["description"].as_s
                  schema_value_raw = test_case["schema"]
                  tests = test_case["tests"].as_a

                  schema_val = JsonSchemaTestSuite.schema_value(schema_value_raw)

                  tests.each do |test|
                    test_description = test["description"].as_s
                    data = test["data"]
                    expected_valid = test["valid"].as_bool

                    it "#{description}: #{test_description}" do
                      schemer = JsonSchemer::Schema.new(
                        schema_val,
                        meta_schema: meta_schema,
                        format: true,
                        ref_resolver: JsonSchemaTestSuite::REF_RESOLVER.to_proc,
                        regexp_resolver: "ecma"
                      )

                      actual_valid = schemer.valid?(data)
                      actual_valid.should eq(expected_valid),
                        "Expected valid=#{expected_valid}, got valid=#{actual_valid}\n" \
                        "  Schema: #{schema_value_raw.to_pretty_json}\n" \
                        "  Data: #{data.to_pretty_json}"
                    end
                  end
                end
              end
            end
          {% end %}
        {% end %}
      {% end %}
    end

    # Format tests (with format validation enabled)
    describe "optional/format" do
      {% for file in `ls #{__DIR__}/../JSON-Schema-Test-Suite/tests/draft2020-12/optional/format/*.json 2>/dev/null || true`.lines %}
        {% if file.size > 0 %}
          {% file_path = file.strip %}
          {% file_name = file_path.split("/").last %}
          {% unless file_name == "" %}
            describe {{ file_name }} do
              file_path = Path.new({{ file_path }})
              file_name = {{ file_name }}

              if JsonSchemaTestSuite.skip_file?(file_name)
                pending "Skipped: #{file_name} (unsupported by Crystal JSON parser)"
              else
                content = File.read(file_path)
                test_cases = JSON.parse(content).as_a

                test_cases.each do |test_case|
                  description = test_case["description"].as_s
                  schema_value_raw = test_case["schema"]
                  tests = test_case["tests"].as_a

                  schema_val = JsonSchemaTestSuite.schema_value(schema_value_raw)

                  tests.each do |test|
                    test_description = test["description"].as_s

                    # Skip specific tests that fail due to UTS#46 vs IDNA2008 differences
                    # ICU uses UTS#46 which maps/allows some characters disallowed in strict IDNA2008
                    if (file_name == "idn-hostname.json" || file_name == "hostname.json") &&
                       (test_description.includes?("U+302E") ||
                        test_description.includes?("Exceptions that are DISALLOWED"))
                      pending "Skipped: #{test_description} (UTS#46 mapping allowed)"
                      next
                    end

                    data = test["data"]
                    expected_valid = test["valid"].as_bool

                    it "#{description}: #{test_description}" do
                      schemer = JsonSchemer::Schema.new(
                        schema_val,
                        meta_schema: meta_schema,
                        format: true,
                        ref_resolver: JsonSchemaTestSuite::REF_RESOLVER.to_proc,
                        regexp_resolver: "ecma"
                      )

                      actual_valid = schemer.valid?(data)
                      actual_valid.should eq(expected_valid),
                        "Expected valid=#{expected_valid}, got valid=#{actual_valid}\n" \
                        "  Schema: #{schema_value_raw.to_pretty_json}\n" \
                        "  Data: #{data.to_pretty_json}"
                    end
                  end
                end
              end
            end
          {% end %}
        {% end %}
      {% end %}
    end
  end
end
