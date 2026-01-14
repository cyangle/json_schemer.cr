module JsonSchemer
  # Resources class for URI-keyed schema storage
  class Resources
    @resources = {} of String => Schema | Keyword

    def [](uri : URI | String) : Schema | Keyword | Nil
      @resources[uri.to_s]?
    end

    def []=(uri : URI | String, resource : Schema | Keyword)
      @resources[uri.to_s] = resource
    end

    def fetch(uri : URI | String) : Schema | Keyword
      @resources[uri.to_s]? || raise KeyError.new("Resource not found: #{uri}")
    end

    def key?(uri : URI | String) : Bool
      @resources.has_key?(uri.to_s)
    end
  end
end
