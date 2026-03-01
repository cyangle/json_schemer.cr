require "./lru_cache"

module JsonSchemer
  # Default maximum cache size for resolver caches
  DEFAULT_RESOLVER_CACHE_SIZE = 1000

  # Generic cached resolver with LRU eviction.
  # Thread-safe: uses a Mutex to synchronize access to the underlying LRUCache.
  #
  # Type parameters:
  # - `K`: The key type passed to the resolver (e.g., `URI`, `String`)
  # - `V`: The value type returned by the resolver (e.g., `JSONHash?`, `Regex?`)
  #
  # The cache key is always `String` (derived via `key.to_s`).
  class CachedResolver(K, V)
    @cache : LRUCache(String, V)
    @mutex : Mutex

    def initialize(max_size : Int32 = DEFAULT_RESOLVER_CACHE_SIZE, &@resolver : Proc(K, V))
      @cache = LRUCache(String, V).new(max_size)
      @mutex = Mutex.new
    end

    def call(key : K) : V
      cache_key = key.to_s

      # Use fetch to get existence + value in one O(1) operation
      # This correctly handles cached nil values
      @mutex.synchronize do
        found, cached = @cache.fetch(cache_key)
        return cached if found
      end

      # Resolve outside the lock to avoid holding it during I/O
      result = @resolver.call(key)

      @mutex.synchronize do
        # Double-check: another fiber may have cached it while we were resolving
        found, cached = @cache.fetch(cache_key)
        return cached if found

        @cache.set(cache_key, result)
      end
      result
    end

    def to_proc : Proc(K, V)
      ->(key : K) { call(key) }
    end

    # Returns the current number of cached entries
    def cache_size : Int32
      @mutex.synchronize { @cache.size }
    end

    # Clears all cached entries
    def clear_cache : Nil
      @mutex.synchronize { @cache.clear }
    end
  end

  # Specialized cached resolver for URI -> JSONHash? with LRU eviction.
  # Thread-safe: uses a Mutex to synchronize access to the underlying LRUCache.
  alias CachedRefResolver = CachedResolver(URI, JSONHash?)

  # Specialized cached resolver for String -> Regex? with LRU eviction.
  # Thread-safe: uses a Mutex to synchronize access to the underlying LRUCache.
  alias CachedRegexpResolver = CachedResolver(String, Regex?)
end
