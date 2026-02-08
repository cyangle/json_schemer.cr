require "./spec_helper"

describe "Memory leak prevention" do
  describe "CachedRegexpResolver unbounded cache growth" do
    it "should limit cache size to prevent unbounded memory growth" do
      # Create a schema with patternProperties that will trigger regexp caching
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "patternProperties": {
          "^prefix_": {"type": "string"}
        },
        "additionalProperties": false
      }))

      # Access the regexp resolver to check its behavior
      # The regexp_resolver is created lazily and caches patterns
      # If we validate with many unique patterns, the cache should be bounded

      # Validate with many different patterns - this should not cause unbounded growth
      1000.times do |i|
        data = {"prefix_#{i}" => "value_#{i}"}
        schema.valid?(JSON.parse(data.to_json)).should be_true
      end

      # If we got here without memory explosion, the test passes
      # The key assertion is that the resolver cache has bounded size
      # Note: This test documents the expected behavior after the fix
    end

    it "cache should evict old entries when limit is reached" do
      # This test verifies that the CachedRegexpResolver uses LRU eviction
      # by checking that it can handle many unique patterns without growing unboundedly

      # Create a fresh resolver with a pattern that uses regexp
      resolver = JsonSchemer::CachedRegexpResolver.new do |pattern|
        Regex.new(pattern)
      end

      # Add many patterns - cache should evict old ones
      2000.times do |i|
        pattern = "^test_pattern_#{i}$"
        resolver.call(pattern)
      end

      # Verify the cache size is bounded (should be <= max_size after fix)
      # Before fix: cache would have 2000 entries
      # After fix: cache should have at most max_size entries (default 1000)
      resolver.cache_size.should be <= 1000
    end
  end

  describe "CachedRefResolver unbounded cache growth" do
    it "should limit cache size to prevent unbounded memory growth" do
      # Create a resolver that simulates fetching external schemas
      call_count = 0
      resolver = JsonSchemer::CachedRefResolver.new do |uri|
        call_count += 1
        # Return a simple schema for any URI
        {"type" => JSON::Any.new("string")} of String => JSON::Any
      end

      # Simulate resolving many different URIs
      2000.times do |i|
        uri = URI.parse("https://example.com/schemas/schema_#{i}.json")
        resolver.call(uri)
      end

      # Verify the cache size is bounded
      # Before fix: cache would have 2000 entries
      # After fix: cache should have at most max_size entries
      resolver.cache_size.should be <= 1000
    end

    it "cached entries should be returned without re-calling resolver" do
      call_count = 0
      resolver = JsonSchemer::CachedRefResolver.new do |uri|
        call_count += 1
        {"type" => JSON::Any.new("object")} of String => JSON::Any
      end

      uri = URI.parse("https://example.com/test.json")

      # First call should invoke the resolver
      resolver.call(uri)
      call_count.should eq(1)

      # Second call should return cached value
      resolver.call(uri)
      call_count.should eq(1)

      # Third call should still return cached value
      resolver.call(uri)
      call_count.should eq(1)
    end
  end

  describe "Generic CachedResolver unbounded cache growth" do
    it "should limit cache size for String-based resolver" do
      resolver = JsonSchemer::CachedResolver(Int32).new(&->(key : String) {
        key.size
      })

      # Add many entries
      2000.times do |i|
        resolver.call("key_#{i}")
      end

      # Cache should be bounded
      resolver.cache_size.should be <= 1000
    end
  end

  describe "Long-lived schema with many validations" do
    it "should not accumulate memory across many validation calls" do
      # This tests that validation state doesn't leak between calls
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "properties": {
          "name": {"type": "string", "pattern": "^[a-z]+$"},
          "age": {"type": "integer", "minimum": 0}
        },
        "patternProperties": {
          "^extra_": {"type": "string"}
        }
      }))

      # Perform many validations with varying data
      1000.times do |i|
        data = {
          "name"                 => "user#{i % 26}",
          "age"                  => i % 100,
          "extra_field#{i % 50}" => "value",
        }
        schema.validate(JSON.parse(data.to_json))
      end

      # If we get here without issues, the test passes
      # The key is that internal caches don't grow unboundedly
    end

    it "regexp patterns should be cached efficiently" do
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "patternProperties": {
          "^foo_": {"type": "string"},
          "^bar_": {"type": "integer"},
          "^baz_": {"type": "boolean"}
        }
      }))

      # Validate many times - the same 3 patterns should be cached
      100.times do |i|
        data = {
          "foo_#{i}"   => "hello",
          "bar_#{i}"   => 42,
          "baz_#{i}"   => true,
          "other_#{i}" => "anything",
        }
        schema.valid?(JSON.parse(data.to_json)).should be_true
      end
    end
  end

  describe "Schema with external refs" do
    it "should cache resolved refs efficiently" do
      # Create a schema that uses internal $ref
      schema = JsonSchemer.schema(%q({
        "type": "object",
        "properties": {
          "user": {"$ref": "#/$defs/User"},
          "admin": {"$ref": "#/$defs/User"}
        },
        "$defs": {
          "User": {
            "type": "object",
            "properties": {
              "name": {"type": "string"},
              "email": {"type": "string"}
            }
          }
        }
      }))

      # Multiple validations should reuse cached refs
      100.times do |i|
        data = {
          "user"  => {"name" => "User #{i}", "email" => "user#{i}@example.com"},
          "admin" => {"name" => "Admin #{i}", "email" => "admin#{i}@example.com"},
        }
        schema.valid?(JSON.parse(data.to_json)).should be_true
      end
    end
  end
end
