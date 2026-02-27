module JsonSchemer
  # Resources class for URI-keyed schema storage
  class Resources
    @resources = {} of String => Schema | Keyword
    @mutex = Mutex.new

    def [](uri : URI | String) : Schema | Keyword | Nil
      @mutex.synchronize { @resources[uri.to_s]? }
    end

    def []=(uri : URI | String, resource : Schema | Keyword)
      @mutex.synchronize { @resources[uri.to_s] = resource }
    end

    def fetch(uri : URI | String) : Schema | Keyword
      @mutex.synchronize { @resources[uri.to_s]? } || raise KeyError.new("Resource not found: #{uri}")
    end

    def key?(uri : URI | String) : Bool
      @mutex.synchronize { @resources.has_key?(uri.to_s) }
    end
  end
end
