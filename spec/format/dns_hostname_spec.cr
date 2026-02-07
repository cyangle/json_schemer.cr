require "../spec_helper"

# Use explicit require if not loaded by default, but it should be via json_schemer.cr
# Just in case, explicit path:
require "../../src/json_schemer/format/dns_hostname"

# Mock resolver for testing without network
class MockResolver < JsonSchemer::DnsResolver
  property mocked_results : Hash(String, Symbol)

  def initialize
    super(60.minutes)
    @mocked_results = {} of String => Symbol
  end

  # Override protected method for testing
  protected def perform_lookup(hostname : String) : Symbol
    @mocked_results[hostname]? || :not_found
  end
end

describe JsonSchemer::Format::DnsHostnameValidator do
  it "validates valid hostnames that exist in DNS" do
    resolver = MockResolver.new
    resolver.mocked_results["example.com"] = :found
    validator = JsonSchemer::Format::DnsHostnameValidator.new(resolver)

    # Valid syntax + Found DNS -> Valid
    validator.call(JSON::Any.new("example.com"), "hostname").should be_true
  end

  it "invalidates valid hostnames that do NOT exist in DNS (NXDOMAIN)" do
    resolver = MockResolver.new
    resolver.mocked_results["nxdomain.example.com"] = :not_found
    validator = JsonSchemer::Format::DnsHostnameValidator.new(resolver)

    # Valid syntax + NotFound DNS -> Invalid
    validator.call(JSON::Any.new("nxdomain.example.com"), "hostname").should be_false
  end

  it "validates valid hostnames when DNS lookup fails (network error fallback)" do
    resolver = MockResolver.new
    resolver.mocked_results["error.example.com"] = :error
    validator = JsonSchemer::Format::DnsHostnameValidator.new(resolver)

    # Valid syntax + Error DNS -> Valid (fallback)
    validator.call(JSON::Any.new("error.example.com"), "hostname").should be_true
  end

  it "invalidates syntactically invalid hostnames regardless of DNS" do
    resolver = MockResolver.new
    resolver.mocked_results["-invalid-.com"] = :found # Even if mocked found
    validator = JsonSchemer::Format::DnsHostnameValidator.new(resolver)

    # Invalid syntax -> Invalid immediately
    validator.call(JSON::Any.new("-invalid-.com"), "hostname").should be_false
  end

  it "handles non-string inputs gracefully" do
    resolver = MockResolver.new
    validator = JsonSchemer::Format::DnsHostnameValidator.new(resolver)

    # Non-string -> Valid (standard JSON Schema format behavior for wrong types)
    validator.call(JSON::Any.new(123_i64), "hostname").should be_true
  end
end
