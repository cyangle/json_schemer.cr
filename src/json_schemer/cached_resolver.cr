require "./lru_cache"

module JsonSchemer
  # Default maximum cache size for resolver caches
  DEFAULT_RESOLVER_CACHE_SIZE = 1000

  # Specialized cached resolver for URI -> JSONHash? with LRU eviction.
  # Thread-safe: uses a Mutex to synchronize access to the underlying LRUCache.
  class CachedRefResolver
    @cache : LRUCache(String, JSONHash?)
    @mutex : Mutex

    def initialize(max_size : Int32 = DEFAULT_RESOLVER_CACHE_SIZE, &@resolver : Proc(URI, JSONHash?))
      @cache = LRUCache(String, JSONHash?).new(max_size)
      @mutex = Mutex.new
    end

    def call(uri : URI) : JSONHash?
      key = uri.to_s

      # Use fetch to get existence + value in one O(1) operation
      # This correctly handles cached nil values
      @mutex.synchronize do
        found, cached = @cache.fetch(key)
        return cached if found
      end

      # Resolve outside the lock to avoid holding it during I/O
      result = @resolver.call(uri)

      @mutex.synchronize do
        # Double-check: another fiber may have cached it while we were resolving
        found, cached = @cache.fetch(key)
        return cached if found

        @cache.set(key, result)
      end
      result
    end

    def to_proc : Proc(URI, JSONHash?)
      ->(uri : URI) { call(uri) }
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

  # Specialized cached resolver for String -> Regex? with LRU eviction.
  # Thread-safe: uses a Mutex to synchronize access to the underlying LRUCache.
  class CachedRegexpResolver
    @cache : LRUCache(String, Regex?)
    @mutex : Mutex

    def initialize(max_size : Int32 = DEFAULT_RESOLVER_CACHE_SIZE, &@resolver : Proc(String, Regex?))
      @cache = LRUCache(String, Regex?).new(max_size)
      @mutex = Mutex.new
    end

    def call(pattern : String) : Regex?
      @mutex.synchronize do
        found, cached = @cache.fetch(pattern)
        return cached if found
      end

      # Resolve outside the lock to avoid holding it during compilation
      result = @resolver.call(pattern)

      @mutex.synchronize do
        # Double-check: another fiber may have cached it while we were resolving
        found, cached = @cache.fetch(pattern)
        return cached if found

        @cache.set(pattern, result)
      end
      result
    end

    def to_proc : Proc(String, Regex?)
      ->(pattern : String) { call(pattern) }
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
end
