module JsonSchemer
  # Cached resolver for ref and regexp resolution
  class CachedResolver(T)
    @cache = {} of String => T

    def initialize(&@resolver : Proc(URI, T))
    end

    def initialize(&@resolver : Proc(String, T))
    end

    def call(key : URI | String) : T
      key_str = key.to_s
      return @cache[key_str] if @cache.has_key?(key_str)

      result = if key.is_a?(URI)
                 @resolver.as(Proc(URI, T)).call(key)
               else
                 @resolver.as(Proc(String, T)).call(key)
               end

      @cache[key_str] = result
      result
    end

    def to_proc : Proc(URI, T) | Proc(String, T)
      ->(key : URI) { call(key) }
    end
  end

  # Specialized cached resolver for URI -> JSONHash?
  class CachedRefResolver
    @cache = {} of String => JSONHash?

    def initialize(&@resolver : Proc(URI, JSONHash?))
    end

    def call(uri : URI) : JSONHash?
      key = uri.to_s
      return @cache[key] if @cache.has_key?(key)
      @cache[key] = @resolver.call(uri)
    end

    def to_proc : Proc(URI, JSONHash?)
      ->(uri : URI) { call(uri) }
    end
  end

  # Specialized cached resolver for String -> Regex?
  class CachedRegexpResolver
    @cache = {} of String => Regex?

    def initialize(&@resolver : Proc(String, Regex?))
    end

    def call(pattern : String) : Regex?
      return @cache[pattern] if @cache.has_key?(pattern)
      @cache[pattern] = @resolver.call(pattern)
    end

    def to_proc : Proc(String, Regex?)
      ->(pattern : String) { call(pattern) }
    end
  end
end
