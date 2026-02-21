require "./lru_cache"

module JsonSchemer
  # Default maximum cache size for resolver caches
  DEFAULT_RESOLVER_CACHE_SIZE = 1000

  # Specialized cached resolver for URI -> JSONHash? with LRU eviction
  class CachedRefResolver
    @cache : LRUCache(String, JSONHash?)

    def initialize(max_size : Int32 = DEFAULT_RESOLVER_CACHE_SIZE, &@resolver : Proc(URI, JSONHash?))
      @cache = LRUCache(String, JSONHash?).new(max_size)
    end

    def call(uri : URI) : JSONHash?
      key = uri.to_s

      # Use fetch to get existence + value in one O(1) operation
      # This correctly handles cached nil values
      found, cached = @cache.fetch(key)
      return cached if found

      # Resolve and cache the result (including nil)
      result = @resolver.call(uri)
      @cache.set(key, result)
      result
    end

    def to_proc : Proc(URI, JSONHash?)
      ->(uri : URI) { call(uri) }
    end

    # Returns the current number of cached entries
    def cache_size : Int32
      @cache.size
    end

    # Clears all cached entries
    def clear_cache : Nil
      @cache.clear
    end
  end

  # Specialized cached resolver for String -> Regex? with LRU eviction
  class CachedRegexpResolver
    @cache : LRUCache(String, Regex?)

    def initialize(max_size : Int32 = DEFAULT_RESOLVER_CACHE_SIZE, &@resolver : Proc(String, Regex?))
      @cache = LRUCache(String, Regex?).new(max_size)
    end

    def call(pattern : String) : Regex?
      # Use fetch to get existence + value in one O(1) operation
      # This correctly handles cached nil values
      found, cached = @cache.fetch(pattern)
      return cached if found

      # Resolve and cache the result (including nil)
      result = @resolver.call(pattern)
      @cache.set(pattern, result)
      result
    end

    def to_proc : Proc(String, Regex?)
      ->(pattern : String) { call(pattern) }
    end

    # Returns the current number of cached entries
    def cache_size : Int32
      @cache.size
    end

    # Clears all cached entries
    def clear_cache : Nil
      @cache.clear
    end
  end
end
