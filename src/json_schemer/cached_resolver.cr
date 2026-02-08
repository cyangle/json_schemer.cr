require "./lru_cache"

module JsonSchemer
  # Default maximum cache size for resolver caches
  DEFAULT_RESOLVER_CACHE_SIZE = 1000

  # Cached resolver for ref and regexp resolution with LRU eviction
  # to prevent unbounded memory growth.
  class CachedResolver(T)
    @cache : LRUCache(String, T)
    @resolver : Proc(URI, T) | Proc(String, T)

    def initialize(max_size : Int32 = DEFAULT_RESOLVER_CACHE_SIZE, &@resolver : Proc(URI, T))
      @cache = LRUCache(String, T).new(max_size)
    end

    def initialize(max_size : Int32 = DEFAULT_RESOLVER_CACHE_SIZE, &@resolver : Proc(String, T))
      @cache = LRUCache(String, T).new(max_size)
    end

    def call(key : URI | String) : T
      key_str = key.to_s

      # Use block-based fetch - returns cached value or computes and caches
      @cache.fetch(key_str) do
        if key.is_a?(URI)
          @resolver.as(Proc(URI, T)).call(key)
        else
          @resolver.as(Proc(String, T)).call(key)
        end
      end
    end

    def to_proc : Proc(URI, T) | Proc(String, T)
      ->(key : URI) { call(key) }
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
