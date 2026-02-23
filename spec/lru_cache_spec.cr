require "./spec_helper"

describe JsonSchemer::LRUCache do
  it "fails with max_size <= 0" do
    expect_raises(ArgumentError, "max_size must be > 0") do
      JsonSchemer::LRUCache(String, String).new(0)
    end

    expect_raises(ArgumentError, "max_size must be > 0") do
      JsonSchemer::LRUCache(String, String).new(-1)
    end
  end

  it "works with valid max_size" do
    cache = JsonSchemer::LRUCache(String, Int32).new(2)
    cache.set("a", 1)
    cache.set("b", 2)
    cache.size.should eq(2)
    cache.get("a").should eq(1)
    cache.get("b").should eq(2)

    cache.set("c", 3)
    cache.size.should eq(2)
    cache.get("a").should be_nil
    cache.get("b").should eq(2)
    cache.get("c").should eq(3)
  end
end
