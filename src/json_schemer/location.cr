module JsonSchemer
  # Location module for JSON pointer handling
  module Location
    JSON_POINTER_TOKEN_ESCAPE_CHARS = {"~" => "~0", "/" => "~1"}
    JSON_POINTER_TOKEN_ESCAPE_REGEX = /[~\/]/

    # Represents a location in the JSON structure
    class Node
      property name : String?
      property parent : Node?
      @children : Hash(String, Node) = {} of String => Node
      @resolved : String?
      @lock : Mutex = Mutex.new(protection: :reentrant)

      def initialize(@name : String? = nil, @parent : Node? = nil)
      end

      def resolve : String
        @resolved || @lock.synchronize do
          @resolved ||= if p = @parent
                          if name = @name
                            "#{p.resolve}/#{Location.escape_json_pointer_token(name)}"
                          else
                            ""
                          end
                        else
                          ""
                        end
        end
      end

      # Get or create a child node
      def join(name : String) : Node
        if node = @children[name]?
          return node
        end

        @lock.synchronize do
          @children[name] ||= Node.new(name, self)
        end
      end
    end

    # Get root location
    def self.root : Node
      Node.new
    end

    # Join a name to a location
    def self.join(location : Node, name : String) : Node
      location.join(name)
    end

    # Resolve location to JSON pointer string
    def self.resolve(location : Node) : String
      location.resolve
    end

    # Escape a token for use in JSON pointer
    def self.escape_json_pointer_token(token : String) : String
      token.gsub(JSON_POINTER_TOKEN_ESCAPE_REGEX) do |match|
        JSON_POINTER_TOKEN_ESCAPE_CHARS[match]
      end
    end
  end
end
