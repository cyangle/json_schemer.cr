require "./spec_helper"
require "../src/json_schemer/dns_resolver"

# Mock resolver for testing timeout/stale behavior
class MockTimeoutResolver < JsonSchemer::DnsResolver
  property simulated_delay : Time::Span? = nil
  property next_result : JsonSchemer::DnsResolver::DnsResult = JsonSchemer::DnsResolver::DnsResult::Found
  property call_count = 0

  # Override to inject delay and result
  protected def perform_lookup(hostname : String) : JsonSchemer::DnsResolver::DnsResult
    @call_count += 1
    if delay = @simulated_delay
      sleep delay
    end
    @next_result
  end
end

describe JsonSchemer::DnsResolver do
  it "respects timeout settings" do
    resolver = MockTimeoutResolver.new(timeout: 100.milliseconds)
    resolver.simulated_delay = 200.milliseconds # Longer than timeout

    # First lookup should timeout and return DnsResult::Error (no stale data)
    resolver.resolve("slow.com").should eq(JsonSchemer::DnsResolver::DnsResult::Error)
  end

  it "returns stale data if lookup times out" do
    resolver = MockTimeoutResolver.new(
      ttl: 10.milliseconds,     # Expires quickly
      stale_ttl: 1.hour,        # Stays stale for long
      timeout: 100.milliseconds # Network timeout
    )

    # A. Initial lookup (fresh)
    resolver.next_result = JsonSchemer::DnsResolver::DnsResult::Found
    resolver.resolve("flakey.com").should eq(JsonSchemer::DnsResolver::DnsResult::Found)

    # Wait for fresh TTL to expire
    sleep 20.milliseconds

    # B. Second lookup (expired but stale) -> Network is slow
    resolver.simulated_delay = 200.milliseconds                          # Trigger timeout
    resolver.next_result = JsonSchemer::DnsResolver::DnsResult::NotFound # Should strictly NOT return this if timed out

    # Should return cached :found value, NOT :error or :not_found
    resolver.resolve("flakey.com").should eq(JsonSchemer::DnsResolver::DnsResult::Found)
  end

  it "uses different TTLs for found vs not_found" do
    resolver = MockTimeoutResolver.new(
      ttl: 1.second,
      not_found_ttl: 100.milliseconds
    )

    # 1. Found -> 1s TTL
    resolver.next_result = JsonSchemer::DnsResolver::DnsResult::Found
    resolver.resolve("exists.com")
    # Immediate retry should hit cache
    resolver.call_count.should eq(1)
    resolver.resolve("exists.com")
    resolver.call_count.should eq(1)

    # 2. Not Found -> 100ms TTL
    resolver.next_result = JsonSchemer::DnsResolver::DnsResult::NotFound
    resolver.resolve("nx.com")
    # Immediate retry should hit cache
    resolver.call_count.should eq(2)
    resolver.resolve("nx.com")
    resolver.call_count.should eq(2)

    # Wait for expiry
    sleep 150.milliseconds

    # Should re-fetch nx.com (expired)
    resolver.resolve("nx.com")
    resolver.call_count.should eq(3)

    # Should still cache exists.com (not expired)
    resolver.resolve("exists.com")
    resolver.call_count.should eq(3)
  end
end
