require "../spec_helper"
require "benchmark"
require "json"

# Helper module for loading test suite
module BenchmarkHelper
  TEST_SUITE_PATH = Path.new(__DIR__).parent.parent / "JSON-Schema-Test-Suite"
  TESTS_PATH      = TEST_SUITE_PATH / "tests"
  REMOTES_PATH    = TEST_SUITE_PATH / "remotes"

  SKIP_FILES = Set{
    "bignum.json",
    "cross-draft.json",
  }

  REF_RESOLVER = JsonSchemer::CachedRefResolver.new do |uri|
    if uri.host == "localhost" && uri.port == 1234
      path = uri.path.not_nil!.lchop('/')
      full_path = REMOTES_PATH / path
      if File.exists?(full_path)
        JsonSchemer::JSONHash.from_json(File.read(full_path))
      else
        nil
      end
    else
      nil
    end
  end

  def self.schema_value(value : JSON::Any) : JSON::Any | JsonSchemer::JSONHash | Bool
    case raw = value.raw
    when Hash
      result = JsonSchemer::JSONHash.new
      raw.each do |k, v|
        result[k.to_s] = v.as(JSON::Any)
      end
      result
    when Bool
      raw
    else
      JsonSchemer::JSONHash.new
    end
  end

  def self.skip_file?(filename : String) : Bool
    SKIP_FILES.includes?(filename)
  end
end

describe "Performance" do
  it "runs simple benchmark" do
    puts "\n--- Simple Schema Benchmark ---"

    schema_def = {
      "type"       => "object",
      "properties" => {
        "firstName" => {"type" => "string"},
        "lastName"  => {"type" => "string"},
        "age"       => {"type" => "integer", "minimum" => 0},
      },
      "required" => ["firstName", "lastName"],
    }

    schema_json = schema_def.to_json
    schema = JsonSchemer.schema(schema_json)

    valid_data = JSON.parse(%q({"firstName": "Jean-Luc", "lastName": "Picard", "age": 51}))
    invalid_data = JSON.parse(%q({"lastName": "Janeway", "age": 41.1}))

    Benchmark.ips do |x|
      x.report("uninitialized, valid, basic") do
        JsonSchemer.schema(schema_json).validate(valid_data, output_format: "basic")
      end

      x.report("uninitialized, invalid, basic") do
        JsonSchemer.schema(schema_json).validate(invalid_data, output_format: "basic")
      end

      x.report("initialized, valid, basic") do
        schema.validate(valid_data, output_format: "basic")
      end

      x.report("initialized, invalid, basic") do
        schema.validate(invalid_data, output_format: "basic")
      end

      x.report("initialized, valid, classic") do
        schema.validate(valid_data, output_format: "classic")
      end

      x.report("initialized, invalid, classic") do
        schema.validate(invalid_data, output_format: "classic")
      end

      x.report("initialized, valid, flag") do
        schema.valid?(valid_data)
      end
    end
  end

  it "runs test suite benchmark" do
    puts "\n--- Test Suite Benchmark (Draft 2020-12) ---"

    test_suite_path = BenchmarkHelper::TEST_SUITE_PATH / "tests/draft2020-12"
    files = Dir.glob(test_suite_path / "**/*.json")

    all_tests = [] of Tuple(JsonSchemer::Schema, JSON::Any, Bool)
    resolver = BenchmarkHelper::REF_RESOLVER.to_proc
    meta_schema = JsonSchemer.draft202012

    print "Loading tests..."
    files.each do |file|
      next if BenchmarkHelper.skip_file?(File.basename(file))

      content = File.read(file)
      test_group = JSON.parse(content).as_a

      test_group.each do |group|
        schema_val = BenchmarkHelper.schema_value(group["schema"])

        begin
          schema = JsonSchemer::Schema.new(
            schema_val,
            meta_schema: meta_schema,
            format: false,
            ref_resolver: resolver,
            regexp_resolver: "ecma"
          )

          # Force initialization of lazy properties if any
          # This helps benchmark pure validation speed

          group["tests"].as_a.each do |test|
            data = test["data"]
            valid = test["valid"].as_bool
            all_tests << {schema, data, valid}
          end
        rescue
          # Skip schema errors during loading
        end
      end
    end
    puts " Done. Loaded #{all_tests.size} tests."

    Benchmark.ips do |x|
      x.report("test suite validation") do
        all_tests.each do |schema, data, expected|
          schema.valid?(data)
        end
      end
    end
  end
end
