#!/usr/bin/env crystal
#
# Comprehensive Memory Profiling for JSON Schema Validation
#
# This file is NOT a spec (no _spec suffix) so it won't run with `crystal spec`.
# Run directly with: crystal run spec/memory_profiling.cr
#
# Purpose: Detect memory leaks during validation by:
# 1. Creating a schema ONCE (not profiled)
# 2. Running 100,000 validations with random data
# 3. Measuring memory before/after to detect leaks
#

require "../src/json_schemer"

# ============================================================================
# Memory Profiling Utilities
# ============================================================================
module MemoryProfiler
  # Get current process memory usage in bytes (RSS from /proc/self/statm)
  def self.current_memory : Int64
    if File.exists?("/proc/self/statm")
      statm = File.read("/proc/self/statm").split
      resident_pages = statm[1].to_i64
      page_size = 4096_i64
      resident_pages * page_size
    else
      GC.stats.heap_size.to_i64
    end
  end

  def self.gc_heap_size : UInt64
    GC.stats.heap_size
  end

  def self.gc_free_bytes : UInt64
    GC.stats.free_bytes
  end

  def self.gc_total_bytes : UInt64
    GC.stats.total_bytes
  end

  def self.force_gc
    GC.collect
  end

  def self.format_bytes(bytes : Int64 | UInt64) : String
    if bytes < 1024
      "#{bytes} B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(2)} KB"
    else
      "#{(bytes / (1024.0 * 1024.0)).round(2)} MB"
    end
  end

  record MemorySnapshot,
    timestamp : Time,
    process_memory : Int64,
    gc_heap_size : UInt64,
    gc_free_bytes : UInt64,
    gc_total_bytes : UInt64 do
    def used_heap : UInt64
      gc_heap_size - gc_free_bytes
    end
  end

  def self.snapshot : MemorySnapshot
    MemorySnapshot.new(
      timestamp: Time.utc,
      process_memory: current_memory,
      gc_heap_size: gc_heap_size,
      gc_free_bytes: gc_free_bytes,
      gc_total_bytes: gc_total_bytes
    )
  end

  def self.print_snapshot(label : String, snap : MemorySnapshot)
    puts "#{label}: Process=#{format_bytes(snap.process_memory)}, " \
         "Heap=#{format_bytes(snap.gc_heap_size)}, " \
         "Used=#{format_bytes(snap.used_heap)}, " \
         "Total=#{format_bytes(snap.gc_total_bytes)}"
  end

  def self.print_diff(label : String, before : MemorySnapshot, after : MemorySnapshot)
    process_diff = after.process_memory - before.process_memory
    heap_diff = after.gc_heap_size.to_i64 - before.gc_heap_size.to_i64
    used_diff = after.used_heap.to_i64 - before.used_heap.to_i64
    total_diff = after.gc_total_bytes.to_i64 - before.gc_total_bytes.to_i64

    puts "#{label}: Process=#{format_bytes(process_diff)}, " \
         "Heap=#{format_bytes(heap_diff)}, " \
         "Used=#{format_bytes(used_diff)}, " \
         "Allocated=#{format_bytes(total_diff)}"
  end
end

# ============================================================================
# Random Data Generator
# ============================================================================
module RandomDataGenerator
  WORDS         = %w[alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega]
  EMAIL_DOMAINS = %w[example.com test.org sample.net demo.io]
  URI_SCHEMES   = %w[http https ftp]
  DATE_FORMATS  = %w[2024-01-15 2023-12-25 2025-06-30 2022-03-10]
  TIME_FORMATS  = %w[10:30:00 14:45:30 08:15:00 23:59:59]
  UUID_CHARS    = ('0'..'9').to_a + ('a'..'f').to_a

  def self.random_string(min_len : Int32 = 1, max_len : Int32 = 50) : String
    len = rand(min_len..max_len)
    String.build do |str|
      len.times { str << ('a'.ord + rand(26)).chr }
    end
  end

  def self.random_word : String
    WORDS.sample
  end

  def self.random_email : String
    "#{random_word}#{rand(1000)}@#{EMAIL_DOMAINS.sample}"
  end

  def self.random_uri : String
    "#{URI_SCHEMES.sample}://#{random_word}.example.com/#{random_word}/#{rand(1000)}"
  end

  def self.random_date : String
    DATE_FORMATS.sample
  end

  def self.random_time : String
    TIME_FORMATS.sample
  end

  def self.random_datetime : String
    "#{random_date}T#{random_time}Z"
  end

  def self.random_uuid : String
    # Generate UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    parts = [8, 4, 4, 4, 12].map do |len|
      String.build do |str|
        len.times { str << UUID_CHARS.sample }
      end
    end
    parts.join("-")
  end

  def self.random_ipv4 : String
    "#{rand(256)}.#{rand(256)}.#{rand(256)}.#{rand(256)}"
  end

  def self.random_integer(min : Int64 = -1000_i64, max : Int64 = 1000_i64) : Int64
    rand(min..max)
  end

  def self.random_number : Float64
    rand * 1000.0 - 500.0
  end

  def self.random_boolean : Bool
    rand(2) == 1
  end

  # Generate a complex object that exercises many validation paths
  def self.generate_complex_instance(iteration : Int32) : Hash(String, JSON::Any)
    result = {} of String => JSON::Any

    # Type validation: all primitive types
    result["string_field"] = JSON::Any.new(random_string(1, 100))
    result["integer_field"] = JSON::Any.new(random_integer)
    result["number_field"] = JSON::Any.new(random_number)
    result["boolean_field"] = JSON::Any.new(random_boolean)
    result["null_field"] = JSON::Any.new(nil)

    # String validations: minLength, maxLength, pattern
    result["name"] = JSON::Any.new(random_string(3, 50))
    result["email"] = JSON::Any.new(random_email)
    result["uri"] = JSON::Any.new(random_uri)
    result["date"] = JSON::Any.new(random_date)
    result["datetime"] = JSON::Any.new(random_datetime)
    result["uuid"] = JSON::Any.new(random_uuid)
    result["ipv4"] = JSON::Any.new(random_ipv4)
    result["pattern_field"] = JSON::Any.new("ABC-#{rand(1000)}")

    # Number validations: minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf
    result["age"] = JSON::Any.new(rand(0_i64..120_i64))
    result["score"] = JSON::Any.new(rand * 100.0)
    result["percentage"] = JSON::Any.new(rand(0_i64..100_i64))
    result["multiple_of_five"] = JSON::Any.new((rand(1..20) * 5).to_i64)

    # Enum and const
    result["status"] = JSON::Any.new(%w[active inactive pending].sample)
    result["version"] = JSON::Any.new("1.0.0")

    # Array validations: minItems, maxItems, uniqueItems, prefixItems, items, contains
    array_size = rand(1..10)
    result["tags"] = JSON::Any.new((0...array_size).map { JSON::Any.new(random_word) })
    result["numbers"] = JSON::Any.new((0...array_size).map { JSON::Any.new(rand(-100_i64..100_i64)) })
    result["tuple"] = JSON::Any.new([
      JSON::Any.new(random_string(1, 10)),
      JSON::Any.new(random_integer),
      JSON::Any.new(random_boolean),
    ])

    # Object validations: properties, additionalProperties, propertyNames, required
    # minProperties, maxProperties, patternProperties, dependentSchemas, dependentRequired
    metadata = {} of String => JSON::Any
    rand(1..5).times do |i|
      metadata["key_#{i}"] = JSON::Any.new(random_string(1, 20))
    end
    result["metadata"] = JSON::Any.new(metadata)

    # Pattern properties - use dynamic keys matching patterns
    rand(1..3).times do |i|
      result["user_#{random_word}_#{i}"] = JSON::Any.new(random_string(1, 30))
      result["item_#{rand(1000)}_#{i}"] = JSON::Any.new(random_integer)
    end

    # Nested objects for $ref testing
    result["address"] = JSON::Any.new({
      "street"  => JSON::Any.new(random_string(5, 50)),
      "city"    => JSON::Any.new(random_word.capitalize),
      "zipcode" => JSON::Any.new(random_string(5, 10)),
      "country" => JSON::Any.new(random_word.upcase[0..1]),
    })

    result["contact"] = JSON::Any.new({
      "primary"   => JSON::Any.new(random_email),
      "secondary" => JSON::Any.new(random_email),
    })

    # Conditional validation (if/then/else)
    if iteration.even?
      result["type"] = JSON::Any.new("individual")
      result["ssn"] = JSON::Any.new("#{rand(100..999)}-#{rand(10..99)}-#{rand(1000..9999)}")
    else
      result["type"] = JSON::Any.new("business")
      result["ein"] = JSON::Any.new("#{rand(10..99)}-#{rand(1000000..9999999)}")
    end

    # AllOf/AnyOf/OneOf testing
    result["value"] = case rand(3)
                      when 0 then JSON::Any.new(random_string(1, 20))
                      when 1 then JSON::Any.new(random_integer)
                      else        JSON::Any.new(random_boolean)
                      end

    # Dependent required
    if random_boolean
      result["credit_card"] = JSON::Any.new(random_string(16, 16))
      result["billing_address"] = JSON::Any.new(random_string(10, 50))
    end

    # Unevaluated properties testing
    if rand(3) == 0
      result["extra_field_#{rand(100)}"] = JSON::Any.new(random_string(1, 20))
    end

    # Nested arrays with objects for complex traversal
    result["items"] = JSON::Any.new((0...rand(1..5)).map do
      JSON::Any.new({
        "id"          => JSON::Any.new(random_integer.abs),
        "name"        => JSON::Any.new(random_string(3, 20)),
        "quantity"    => JSON::Any.new(rand(1_i64..100_i64)),
        "price"       => JSON::Any.new(rand * 1000.0),
        "in_stock"    => JSON::Any.new(random_boolean),
        "category"    => JSON::Any.new(random_word),
        "subcategory" => JSON::Any.new(random_word),
      })
    end)

    # Deep nesting for Location::Node tree testing
    result["deep"] = JSON::Any.new({
      "level1" => JSON::Any.new({
        "level2" => JSON::Any.new({
          "level3" => JSON::Any.new({
            "level4" => JSON::Any.new({
              "value" => JSON::Any.new(random_string(1, 10)),
            }),
          }),
        }),
      }),
    })

    # Dynamic ref testing structure
    if rand(2) == 0
      result["tree"] = JSON::Any.new({
        "value"    => JSON::Any.new(random_string(1, 10)),
        "children" => JSON::Any.new([
          JSON::Any.new({
            "value"    => JSON::Any.new(random_string(1, 10)),
            "children" => JSON::Any.new([] of JSON::Any),
          }),
        ]),
      })
    end

    result
  end
end

# ============================================================================
# Comprehensive Schema Definition
# ============================================================================
# This schema exercises ALL major keywords:
# - Core: $id, $ref, $defs, $anchor, $dynamicAnchor, $dynamicRef
# - Validation: type, enum, const, multipleOf, min/max for numbers/strings/arrays/objects
# - Applicator: allOf, anyOf, oneOf, not, if/then/else, properties, patternProperties,
#               additionalProperties, prefixItems, items, contains, dependentSchemas
# - Unevaluated: unevaluatedProperties, unevaluatedItems
# - Format: various format validators
# - Content: contentEncoding, contentMediaType (if applicable)
# - MetaData: readOnly, writeOnly, default
#
COMPREHENSIVE_SCHEMA = %q({
  "$id": "https://example.com/comprehensive-schema",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["name", "email", "status", "age"],

  "properties": {
    "string_field": {"type": "string"},
    "integer_field": {"type": "integer"},
    "number_field": {"type": "number"},
    "boolean_field": {"type": "boolean"},
    "null_field": {"type": "null"},

    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100,
      "pattern": "^[a-zA-Z]"
    },

    "email": {
      "type": "string",
      "pattern": "^[^@]+@[^@]+\\.[^@]+$"
    },

    "uri": {"type": "string"},
    "date": {"type": "string", "pattern": "^\\d{4}-\\d{2}-\\d{2}$"},
    "datetime": {"type": "string"},
    "uuid": {"type": "string", "pattern": "^[0-9a-f-]{36}$"},
    "ipv4": {"type": "string", "pattern": "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$"},
    "pattern_field": {"type": "string", "pattern": "^[A-Z]{3}-\\d+$"},

    "age": {
      "type": "integer",
      "minimum": 0,
      "maximum": 150
    },

    "score": {
      "type": "number",
      "minimum": 0,
      "maximum": 100
    },

    "percentage": {
      "type": "integer",
      "minimum": 0,
      "exclusiveMaximum": 101
    },

    "multiple_of_five": {
      "type": "integer",
      "multipleOf": 5
    },

    "status": {
      "enum": ["active", "inactive", "pending"]
    },

    "version": {
      "const": "1.0.0"
    },

    "tags": {
      "type": "array",
      "items": {"type": "string", "minLength": 1},
      "minItems": 0,
      "maxItems": 20,
      "uniqueItems": true
    },

    "numbers": {
      "type": "array",
      "items": {"type": "integer"},
      "contains": {"minimum": -50, "maximum": 50}
    },

    "tuple": {
      "type": "array",
      "prefixItems": [
        {"type": "string"},
        {"type": "integer"},
        {"type": "boolean"}
      ],
      "items": false
    },

    "metadata": {
      "type": "object",
      "additionalProperties": {"type": "string"},
      "propertyNames": {"pattern": "^[a-z_]+$"},
      "minProperties": 0,
      "maxProperties": 10
    },

    "address": {"$ref": "#/$defs/Address"},
    "contact": {"$ref": "#/$defs/Contact"},

    "type": {
      "type": "string",
      "enum": ["individual", "business"]
    },

    "value": {
      "oneOf": [
        {"type": "string"},
        {"type": "integer"},
        {"type": "boolean"}
      ]
    },

    "items": {
      "type": "array",
      "items": {"$ref": "#/$defs/Item"}
    },

    "deep": {
      "type": "object",
      "properties": {
        "level1": {
          "type": "object",
          "properties": {
            "level2": {
              "type": "object",
              "properties": {
                "level3": {
                  "type": "object",
                  "properties": {
                    "level4": {
                      "type": "object",
                      "properties": {
                        "value": {"type": "string"}
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    },

    "tree": {"$ref": "#/$defs/TreeNode"}
  },

  "patternProperties": {
    "^user_": {"type": "string"},
    "^item_\\d+": {"type": "integer"}
  },

  "additionalProperties": true,

  "if": {
    "properties": {"type": {"const": "individual"}},
    "required": ["type"]
  },
  "then": {
    "properties": {
      "ssn": {"type": "string", "pattern": "^\\d{3}-\\d{2}-\\d{4}$"}
    }
  },
  "else": {
    "properties": {
      "ein": {"type": "string", "pattern": "^\\d{2}-\\d{7}$"}
    }
  },

  "dependentRequired": {
    "credit_card": ["billing_address"]
  },

  "dependentSchemas": {
    "credit_card": {
      "properties": {
        "billing_address": {"type": "string", "minLength": 1}
      }
    }
  },

  "$defs": {
    "Address": {
      "type": "object",
      "properties": {
        "street": {"type": "string"},
        "city": {"type": "string"},
        "zipcode": {"type": "string"},
        "country": {"type": "string", "minLength": 2, "maxLength": 2}
      },
      "required": ["city"]
    },

    "Contact": {
      "type": "object",
      "properties": {
        "primary": {"type": "string"},
        "secondary": {"type": "string"}
      },
      "required": ["primary"]
    },

    "Item": {
      "type": "object",
      "properties": {
        "id": {"type": "integer", "minimum": 0},
        "name": {"type": "string", "minLength": 1},
        "quantity": {"type": "integer", "minimum": 1},
        "price": {"type": "number", "minimum": 0},
        "in_stock": {"type": "boolean"},
        "category": {"type": "string"},
        "subcategory": {"type": "string"}
      },
      "required": ["id", "name"]
    },

    "TreeNode": {
      "$anchor": "tree-node",
      "type": "object",
      "properties": {
        "value": {"type": "string"},
        "children": {
          "type": "array",
          "items": {"$ref": "#tree-node"}
        }
      },
      "required": ["value"]
    }
  }
})

# ============================================================================
# Main Profiling Execution
# ============================================================================
def run_memory_profiling
  puts "=" * 80
  puts "JSON Schema Validation Memory Profiling"
  puts "=" * 80
  puts

  iterations = 100_000
  snapshot_interval = 10_000

  # Phase 1: Create schema (NOT profiled for leaks, but we measure it)
  puts "Phase 1: Schema Creation"
  puts "-" * 40

  MemoryProfiler.force_gc
  sleep 0.1.seconds
  before_schema = MemoryProfiler.snapshot
  MemoryProfiler.print_snapshot("Before schema creation", before_schema)

  schema = JsonSchemer.schema(COMPREHENSIVE_SCHEMA)

  MemoryProfiler.force_gc
  sleep 0.1.seconds
  after_schema = MemoryProfiler.snapshot
  MemoryProfiler.print_snapshot("After schema creation", after_schema)
  MemoryProfiler.print_diff("Schema creation cost", before_schema, after_schema)
  puts

  # Warmup: Run a few validations to stabilize JIT and caches
  puts "Phase 2: Warmup (100 validations)"
  puts "-" * 40
  100.times do |i|
    data = RandomDataGenerator.generate_complex_instance(i)
    schema.validate(JSON::Any.new(data))
  end

  MemoryProfiler.force_gc
  sleep 0.2.seconds
  after_warmup = MemoryProfiler.snapshot
  MemoryProfiler.print_snapshot("After warmup", after_warmup)
  puts

  # Phase 3: Main profiling - 100,000 validations
  puts "Phase 3: Main Validation Profiling (#{iterations} iterations)"
  puts "-" * 40

  MemoryProfiler.force_gc
  sleep 0.2.seconds
  baseline = MemoryProfiler.snapshot
  MemoryProfiler.print_snapshot("Baseline", baseline)

  snapshots = [] of Tuple(Int32, MemoryProfiler::MemorySnapshot)
  start_time = Time.utc

  iterations.times do |i|
    # Generate completely new random data each iteration
    data = RandomDataGenerator.generate_complex_instance(i)

    # ONLY profile validation - schema already created
    result = schema.validate(JSON::Any.new(data))

    # Discard the result immediately to ensure it doesn't hold memory
    # (In real usage, results are typically processed and discarded)

    # Take snapshot at intervals
    if (i + 1) % snapshot_interval == 0
      MemoryProfiler.force_gc
      snap = MemoryProfiler.snapshot
      snapshots << {i + 1, snap}
      elapsed = (Time.utc - start_time).total_seconds
      rate = (i + 1) / elapsed
      puts "  #{i + 1}: Used=#{MemoryProfiler.format_bytes(snap.used_heap)}, " \
           "Total=#{MemoryProfiler.format_bytes(snap.gc_total_bytes)}, " \
           "Rate=#{rate.round(0)} validations/sec"
    end
  end

  end_time = Time.utc
  total_elapsed = (end_time - start_time).total_seconds

  # Final measurement
  MemoryProfiler.force_gc
  sleep 0.3.seconds
  final = MemoryProfiler.snapshot

  puts
  puts "Final Results:"
  puts "-" * 40
  MemoryProfiler.print_snapshot("Final state", final)
  MemoryProfiler.print_diff("Total growth during validation", baseline, final)
  puts
  puts "Performance: #{iterations} validations in #{total_elapsed.round(2)}s " \
       "(#{(iterations / total_elapsed).round(0)} validations/sec)"
  puts

  # Analysis: Check for memory leak indicators
  puts "Memory Leak Analysis:"
  puts "-" * 40

  used_growth = final.used_heap.to_i64 - baseline.used_heap.to_i64
  process_growth = final.process_memory - baseline.process_memory

  # Check if memory grew linearly with iterations (leak indicator)
  if snapshots.size >= 2
    first_snap = snapshots.first[1]
    last_snap = snapshots.last[1]
    growth_per_10k = (last_snap.used_heap.to_i64 - first_snap.used_heap.to_i64) /
                     ((snapshots.last[0] - snapshots.first[0]) / 10_000)

    puts "Memory growth per 10K validations: #{MemoryProfiler.format_bytes(growth_per_10k.to_i64)}"

    # If growth per 10K exceeds 1MB, likely a leak
    if growth_per_10k > 1024 * 1024
      puts "⚠️  WARNING: Possible memory leak detected!"
      puts "   Memory is growing linearly with iterations."
    else
      puts "✅ No significant linear memory growth detected."
    end
  end

  # Check absolute growth
  max_acceptable_growth = 50 * 1024 * 1024 # 50MB for 100K validations
  if used_growth > max_acceptable_growth
    puts "⚠️  WARNING: High absolute memory growth: #{MemoryProfiler.format_bytes(used_growth)}"
  else
    puts "✅ Absolute memory growth within acceptable limits: #{MemoryProfiler.format_bytes(used_growth)}"
  end

  # Additional diagnostics
  puts
  puts "Detailed Snapshot History:"
  puts "-" * 40
  prev_used : UInt64 = baseline.used_heap
  snapshots.each do |(count, snap)|
    diff = snap.used_heap.to_i64 - prev_used.to_i64
    puts "  #{count}: Used=#{MemoryProfiler.format_bytes(snap.used_heap)} (#{diff >= 0 ? "+" : ""}#{MemoryProfiler.format_bytes(diff)})"
    prev_used = snap.used_heap
  end

  puts
  puts "=" * 80
  puts "Profiling Complete"
  puts "=" * 80

  # Return exit code based on leak detection
  if used_growth > max_acceptable_growth
    exit 1
  else
    exit 0
  end
end

# Run the profiling
run_memory_profiling
