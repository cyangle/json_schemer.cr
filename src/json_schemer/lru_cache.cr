module JsonSchemer
  # A performant Least Recently Used (LRU) cache using a Hash and a Doubly Linked List.
  # All operations are O(1).
  #
  # NOTE: This class is not thread-safe. Synchronization must be handled by the caller.
  private class LRUCache(K, V)
    private class Node(K, V)
      property key : K
      property value : V
      property prev : Node(K, V)?
      property next : Node(K, V)?

      def initialize(@key : K, @value : V)
      end
    end

    @cache = Hash(K, Node(K, V)).new
    @head : Node(K, V)? # Most recent
    @tail : Node(K, V)? # Least recent

    getter size : Int32 = 0
    getter max_size : Int32

    def initialize(@max_size : Int32)
    end

    def get(key : K) : V?
      if node = @cache[key]?
        move_to_front(node)
        node.value
      end
    end

    def set(key : K, value : V) : V
      if node = @cache[key]?
        node.value = value
        move_to_front(node)
      else
        node = Node(K, V).new(key, value)
        @cache[key] = node
        add_to_front(node)
        @size += 1

        if @size > @max_size
          evict_least_recent
        end
      end
      value
    end

    def delete(key : K) : V?
      if node = @cache.delete(key)
        remove_node(node)
        @size -= 1
        node.value
      end
    end

    def clear
      @cache.clear
      @head = nil
      @tail = nil
      @size = 0
    end

    private def move_to_front(node : Node(K, V))
      return if node == @head

      remove_node(node)
      add_to_front(node)
    end

    private def add_to_front(node : Node(K, V))
      node.next = @head
      node.prev = nil

      if h = @head
        h.prev = node
      end

      @head = node
      @tail = node if @tail.nil?
    end

    private def remove_node(node : Node(K, V))
      if p = node.prev
        p.next = node.next
      else
        @head = node.next
      end

      if n = node.next
        n.prev = node.prev
      else
        @tail = node.prev
      end
    end

    private def evict_least_recent
      if t = @tail
        @cache.delete(t.key)
        remove_node(t)
        @size -= 1
      end
    end
  end
end
