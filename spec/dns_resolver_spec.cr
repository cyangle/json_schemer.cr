require "./spec_helper"
require "../src/json_schemer/dns_resolver"

class MockDnsResolverForCache < JsonSchemer::DnsResolver
  property lookup_count = 0
  property next_result : Symbol = :found
  property delay : Time::Span? = nil

  protected def perform_lookup(hostname : String) : Symbol
    @lookup_count += 1
    if d = @delay
      sleep d
    end
    @next_result
  end
end

describe JsonSchemer::DnsResolver do
  it "caches results for the specified TTL" do
    resolver = MockDnsResolverForCache.new(1.second)

    # First lookup
    resolver.resolve("example.com").should eq(:found)
    resolver.lookup_count.should eq(1)

    # Second lookup (cached)
    resolver.resolve("example.com").should eq(:found)
    resolver.lookup_count.should eq(1)

    # Wait for expiry
    sleep 1.1.seconds

    # Third lookup (expired, re-fetch)
    resolver.resolve("example.com").should eq(:found)
    resolver.lookup_count.should eq(2)
  end

  it "caches negative results (not found) with specific TTL" do
    resolver = MockDnsResolverForCache.new(ttl: 1.hour, not_found_ttl: 1.second)
    resolver.next_result = :not_found

    resolver.resolve("nx.com").should eq(:not_found)
    resolver.lookup_count.should eq(1)

    resolver.resolve("nx.com").should eq(:not_found)
    resolver.lookup_count.should eq(1)

    sleep 1.1.seconds

    resolver.resolve("nx.com").should eq(:not_found)
    resolver.lookup_count.should eq(2)
  end

  it "falls back to stale data on timeout" do
    resolver = MockDnsResolverForCache.new(
      ttl: 1.second,
      stale_ttl: 1.hour,
      timeout: 500.milliseconds
    )

    # 1. Populate cache
    resolver.resolve("example.com").should eq(:found)
    resolver.lookup_count.should eq(1)

    # 2. Wait for soft expiry
    sleep 1.1.seconds

    # 3. Trigger a lookup that will timeout
    resolver.delay = 1.second
    resolver.resolve("example.com").should eq(:found) # Should return stale entry
    resolver.lookup_count.should eq(2)                # It tried to lookup
  end

  it "returns error on timeout if no stale data" do
    resolver = MockDnsResolverForCache.new(timeout: 500.milliseconds)
    resolver.delay = 1.second

    resolver.resolve("new.com").should eq(:error)
  end

  it "calculates stale TTL relative to expiry time" do
    # ttl = 1s, stale_ttl = 1s
    # New logic: soft expiry at T+1s, hard expiry at T+1s + 1s = T+2s
    resolver = MockDnsResolverForCache.new(
      ttl: 1.second,
      stale_ttl: 1.second,
      timeout: 500.milliseconds
    )

    # 1. Populate cache
    resolver.resolve("example.com").should eq(:found)
    resolver.lookup_count.should eq(1)

    # 2. Wait past soft expiry (1s) but before hard expiry (2s)
    sleep 1.2.seconds

    # 3. Trigger a lookup that will timeout
    resolver.delay = 1.second
    # Should return stale data (:found) because 1.2s < (1s + 1s)
    resolver.resolve("example.com").should eq(:found)
    resolver.lookup_count.should eq(2)

    # 4. Wait past hard expiry (2s)
    sleep 1.0.seconds # Total 2.2s

    # 5. Trigger another lookup that will timeout
    resolver.resolve("example.com").should eq(:error)
    resolver.lookup_count.should eq(3)
  end

  it "has a default timeout of 10 seconds" do
    resolver = MockDnsResolverForCache.new
    resolver.timeout.should eq(10.seconds)
  end
end
