# json_schemer.cr

A Crystal port of the Ruby [json_schemer](https://github.com/davishmcclurg/json_schemer) library for validating JSON documents against [JSON Schema](https://json-schema.org/).

[![Crystal Version](https://img.shields.io/badge/crystal-%3E%3D1.18.2-blue.svg)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **JSON Schema Draft 2020-12** compliant
- **OpenAPI 3.1** schema validation support
- Multiple output formats: `flag`, `basic`, `classic`
- Custom format validators
- Custom ref resolvers (file, HTTP, custom)
- ECMA-262 compatible regex patterns
- `$ref`, `$anchor`, `$dynamicRef` / `$dynamicAnchor` support
- Complete vocabulary implementations

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     json_schemer:
       github: cyangle/json_schemer.cr
   ```

2. Run `shards install`

## Quick Start

```crystal
require "json_schemer"

# Create a schema
schema = JsonSchemer.schema(%q({
  "type": "object",
  "required": ["name", "email"],
  "properties": {
    "name": {"type": "string", "minLength": 1},
    "email": {"type": "string"},
    "age": {"type": "integer", "minimum": 0}
  }
}))

# Validate data
valid_data = JSON.parse(%q({"name": "John", "email": "john@example.com", "age": 30}))
schema.valid?(valid_data)  # => true

invalid_data = JSON.parse(%q({"name": "", "age": -5}))
schema.valid?(invalid_data)  # => false (name too short, missing email, age < 0)
```

## Usage

### Creating Schemas

```crystal
require "json_schemer"

# From a JSON string
schema = JsonSchemer.schema(%q({"type": "string"}))

# From a Hash
schema = JsonSchemer.schema({"type" => JSON::Any.new("string")} of String => JSON::Any)

# From parsed JSON
schema = JsonSchemer.schema(JSON.parse(%q({"type": "object"})).as_h)

# From a file path (enables relative $ref resolution)
schema = JsonSchemer.schema(Path.new("schemas/my_schema.json"))
```

### Basic Validation

```crystal
schema = JsonSchemer.schema(%q({"type": "integer", "minimum": 0, "maximum": 100}))

# Check if valid
schema.valid?(JSON::Any.new(50_i64))   # => true
schema.valid?(JSON::Any.new(150_i64))  # => false
schema.valid?(JSON::Any.new("text"))   # => false
```

### Getting Validation Errors

```crystal
schema = JsonSchemer.schema(%q({
  "type": "object",
  "required": ["name"],
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "integer"}
  }
}))

data = JSON.parse(%q({"age": "not a number"}))
result = schema.validate(data, output_format: "classic")

# Access errors
if !result["valid"].as_bool
  result["errors"].as_a.each do |error|
    puts "Error at #{error["data_pointer"]}: #{error["error"]}"
  end
end
```

### Output Formats

```crystal
schema = JsonSchemer.schema(%q({"type": "string"}))
data = JSON::Any.new(42_i64)

# Flag format - just valid/invalid
result = schema.validate(data, output_format: "flag")
# {"valid" => false}

# Basic format - includes error list
result = schema.validate(data, output_format: "basic")
# {"valid" => false, "errors" => [...]}

# Classic format - detailed errors with pointers (default)
result = schema.validate(data, output_format: "classic")
# {"valid" => false, "errors" => [...with data_pointer, schema_pointer, type, error...]}
```

### Type Validation

```crystal
# Single type
JsonSchemer.schema(%q({"type": "string"})).valid?(JSON::Any.new("hello"))  # => true
JsonSchemer.schema(%q({"type": "integer"})).valid?(JSON::Any.new(42_i64))  # => true
JsonSchemer.schema(%q({"type": "number"})).valid?(JSON::Any.new(3.14))     # => true
JsonSchemer.schema(%q({"type": "boolean"})).valid?(JSON::Any.new(true))    # => true
JsonSchemer.schema(%q({"type": "null"})).valid?(JSON::Any.new(nil))        # => true
JsonSchemer.schema(%q({"type": "array"})).valid?(JSON.parse("[]"))         # => true
JsonSchemer.schema(%q({"type": "object"})).valid?(JSON.parse("{}"))        # => true

# Multiple types
schema = JsonSchemer.schema(%q({"type": ["string", "integer"]}))
schema.valid?(JSON::Any.new("hello"))  # => true
schema.valid?(JSON::Any.new(42_i64))   # => true
schema.valid?(JSON::Any.new(3.14))     # => false
```

### Numeric Constraints

```crystal
schema = JsonSchemer.schema(%q({
  "type": "number",
  "minimum": 0,
  "maximum": 100,
  "exclusiveMinimum": 0,
  "exclusiveMaximum": 100,
  "multipleOf": 5
}))

schema.valid?(JSON::Any.new(50_i64))   # => true (multiple of 5, in range)
schema.valid?(JSON::Any.new(0_i64))    # => false (not exclusive > 0)
schema.valid?(JSON::Any.new(100_i64))  # => false (not exclusive < 100)
schema.valid?(JSON::Any.new(53_i64))   # => false (not multiple of 5)
```

### String Constraints

```crystal
schema = JsonSchemer.schema(%q({
  "type": "string",
  "minLength": 2,
  "maxLength": 10,
  "pattern": "^[a-z]+$"
}))

schema.valid?(JSON::Any.new("hello"))  # => true
schema.valid?(JSON::Any.new("x"))      # => false (too short)
schema.valid?(JSON::Any.new("Hello"))  # => false (uppercase fails pattern)
```

### Array Validation

```crystal
# Basic array constraints
schema = JsonSchemer.schema(%q({
  "type": "array",
  "minItems": 1,
  "maxItems": 5,
  "uniqueItems": true,
  "items": {"type": "integer"}
}))

schema.valid?(JSON.parse("[1, 2, 3]"))      # => true
schema.valid?(JSON.parse("[]"))             # => false (minItems)
schema.valid?(JSON.parse("[1, 1, 2]"))      # => false (uniqueItems)
schema.valid?(JSON.parse(%q([1, "two"])))   # => false (items type)

# Tuple validation with prefixItems
schema = JsonSchemer.schema(%q({
  "type": "array",
  "prefixItems": [
    {"type": "string"},
    {"type": "integer"}
  ]
}))
schema.valid?(JSON.parse(%q(["name", 42])))  # => true
schema.valid?(JSON.parse(%q([42, "name"])))  # => false

# Contains with min/max
schema = JsonSchemer.schema(%q({
  "type": "array",
  "contains": {"type": "integer"},
  "minContains": 2,
  "maxContains": 3
}))
schema.valid?(JSON.parse("[1, 2, 'a']"))     # => true (2 integers)
schema.valid?(JSON.parse("[1, 'a', 'b']"))   # => false (only 1 integer)
```

### Object Validation

```crystal
schema = JsonSchemer.schema(%q({
  "type": "object",
  "required": ["name"],
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "integer", "minimum": 0}
  },
  "additionalProperties": false
}))

schema.valid?(JSON.parse(%q({"name": "John", "age": 30})))  # => true
schema.valid?(JSON.parse(%q({"age": 30})))                  # => false (missing required)
schema.valid?(JSON.parse(%q({"name": "John", "extra": 1}))) # => false (additional prop)

# Pattern properties
schema = JsonSchemer.schema(%q({
  "type": "object",
  "patternProperties": {
    "^x-": {"type": "string"}
  }
}))
schema.valid?(JSON.parse(%q({"x-custom": "value"})))  # => true
schema.valid?(JSON.parse(%q({"x-custom": 123})))      # => false

# Property name validation
schema = JsonSchemer.schema(%q({
  "type": "object",
  "propertyNames": {"pattern": "^[a-z]+$"}
}))
schema.valid?(JSON.parse(%q({"foo": 1})))   # => true
schema.valid?(JSON.parse(%q({"Foo": 1})))   # => false
```

### Combinators

```crystal
# allOf - must match all schemas
schema = JsonSchemer.schema(%q({
  "allOf": [
    {"type": "object"},
    {"required": ["name"]}
  ]
}))

# anyOf - must match at least one schema
schema = JsonSchemer.schema(%q({
  "anyOf": [
    {"type": "string"},
    {"type": "integer"}
  ]
}))

# oneOf - must match exactly one schema
schema = JsonSchemer.schema(%q({
  "oneOf": [
    {"type": "integer", "minimum": 0},
    {"type": "integer", "maximum": 0}
  ]
}))
schema.valid?(JSON::Any.new(5_i64))   # => true (matches first only)
schema.valid?(JSON::Any.new(-5_i64))  # => true (matches second only)
schema.valid?(JSON::Any.new(0_i64))   # => false (matches both!)

# not - must NOT match the schema
schema = JsonSchemer.schema(%q({
  "not": {"type": "string"}
}))
schema.valid?(JSON::Any.new(42_i64))     # => true
schema.valid?(JSON::Any.new("hello"))    # => false
```

### Conditional Validation

```crystal
schema = JsonSchemer.schema(%q({
  "if": {"properties": {"type": {"const": "person"}}},
  "then": {"required": ["name"]},
  "else": {"required": ["title"]}
}))

schema.valid?(JSON.parse(%q({"type": "person", "name": "John"})))     # => true
schema.valid?(JSON.parse(%q({"type": "book", "title": "Moby Dick"}))) # => true
schema.valid?(JSON.parse(%q({"type": "person", "title": "Mr"})))      # => false

# Dependent required
schema = JsonSchemer.schema(%q({
  "dependentRequired": {
    "credit_card": ["billing_address"]
  }
}))
schema.valid?(JSON.parse(%q({})))                                           # => true
schema.valid?(JSON.parse(%q({"credit_card": "1234", "billing_address": "..."}))) # => true
schema.valid?(JSON.parse(%q({"credit_card": "1234"})))                      # => false
```

### References ($ref)

```crystal
# Internal references with $defs
schema = JsonSchemer.schema(%q({
  "$defs": {
    "positiveInteger": {
      "type": "integer",
      "minimum": 1
    }
  },
  "type": "object",
  "properties": {
    "count": {"$ref": "#/$defs/positiveInteger"}
  }
}))

# Recursive schema
schema = JsonSchemer.schema(%q({
  "$id": "https://example.com/tree",
  "type": "object",
  "properties": {
    "value": {"type": "integer"},
    "children": {
      "type": "array",
      "items": {"$ref": "#"}
    }
  }
}))

# $anchor references
schema = JsonSchemer.schema(%q({
  "$defs": {
    "address": {
      "$anchor": "addressSchema",
      "type": "object",
      "properties": {"street": {"type": "string"}}
    }
  },
  "properties": {
    "home": {"$ref": "#addressSchema"}
  }
}))

# $dynamicRef and $dynamicAnchor
schema = JsonSchemer.schema(%q({
  "$id": "https://example.com/schema",
  "$dynamicAnchor": "node",
  "type": "object",
  "properties": {
    "value": {"type": "integer"},
    "next": {"$dynamicRef": "#node"}
  }
}))
```

### Custom Ref Resolver

```crystal
# Resolve external references
external_schemas = {
  "http://example.com/user.json" => JSON.parse(%q({
    "type": "object",
    "properties": {
      "name": {"type": "string"}
    }
  })).as_h
}

schema = JsonSchemer.schema(
  %q({"$ref": "http://example.com/user.json"}),
  ref_resolver: ->(uri : URI) {
    external_schemas[uri.to_s]?
  }
)
```

### Format Validation

By default in Draft 2020-12, format is annotation-only (doesn't cause validation failures). Use `format: true` to enable format validation:

```crystal
# Annotation only (default)
schema = JsonSchemer.schema(%q({"format": "email"}), format: false)
schema.valid?(JSON::Any.new("not-an-email"))  # => true (format is just annotation)

# Assertion mode
schema = JsonSchemer.schema(%q({"format": "email"}), format: true)
schema.valid?(JSON::Any.new("user@example.com"))  # => true
schema.valid?(JSON::Any.new("not-an-email"))      # => false
```

Supported formats:
- `email`, `idn-email`
- `date-time`, `date`, `time`, `duration`
- `hostname`, `idn-hostname`
- `uri`, `uri-reference`, `uri-template`, `iri`, `iri-reference`
- `ipv4`, `ipv6`
- `uuid`
- `json-pointer`, `relative-json-pointer`
- `regex`

### Custom Format Validators

```crystal
schema = JsonSchemer.schema(
  %q({"format": "custom-format"}),
  format: true,
  formats: {
    "custom-format" => ->(value : JSON::Any, format : String) {
      value.as_s? == "valid"
    }
  }
)

schema.valid?(JSON::Any.new("valid"))    # => true
schema.valid?(JSON::Any.new("invalid"))  # => false
```

### Pretty Error Formatting

Use the `Errors.pretty` helper for human-readable error messages:

```crystal
schema = JsonSchemer.schema(%q({
  "type": "object",
  "required": ["name"],
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "integer"}
  }
}))

data = JSON.parse(%q({"age": "not a number"}))
result = schema.validate(data, output_format: "classic")

result["errors"].as_a.each do |error|
  puts JsonSchemer::Errors.pretty(error.as_h)
end
# Output:
# root is missing required keys: name
# property '/age' is not of type: integer
```

### Meta-Schema Validation

Validate that a schema itself is valid:

```crystal
# Check if a schema is valid
JsonSchemer.valid_schema?({"type" => JSON::Any.new("string")})  # => true
JsonSchemer.valid_schema?({"type" => JSON::Any.new("invalid")}) # => false

# Get detailed validation errors for invalid schemas
result = JsonSchemer.validate_schema({"type" => JSON::Any.new("invalid")})
puts result["errors"]
```

### OpenAPI 3.1 Support

```crystal
document = JSON.parse(%q({
  "openapi": "3.1.0",
  "info": {"title": "My API", "version": "1.0.0"},
  "paths": {},
  "components": {
    "schemas": {
      "User": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "integer"}
        },
        "required": ["name"]
      }
    }
  }
})).as_h

# Create OpenAPI document handler
openapi = JsonSchemer.openapi(document)

# Validate the document itself
openapi.valid?  # => true

# Get individual component schemas
user_schema = openapi.schema("User")
user_schema.valid?(JSON.parse(%q({"name": "John"})))  # => true
user_schema.valid?(JSON.parse(%q({"age": 30})))       # => false (missing name)
```

### Access Mode (readOnly/writeOnly)

```crystal
schema_hash = JSON.parse(%q({
  "type": "object",
  "properties": {
    "id": {"type": "integer", "readOnly": true},
    "password": {"type": "string", "writeOnly": true}
  },
  "required": ["id", "password"]
})).as_h

# Read mode: writeOnly properties are not required
read_schema = JsonSchemer.schema(schema_hash, access_mode: "read")
read_schema.valid?(JSON.parse(%q({"id": 1})))  # => true

# Write mode: readOnly properties are not required
write_schema = JsonSchemer.schema(schema_hash, access_mode: "write")
write_schema.valid?(JSON.parse(%q({"password": "secret"})))  # => true
```

### ECMA-262 Regex Compatibility

```crystal
# Use ECMA-262 regex patterns (JavaScript-compatible)
schema = JsonSchemer.schema(
  %q({"pattern": "^\\\\p{L}+$"}),
  regexp_resolver: "ecma"
)
```

## Configuration Reference

This section provides a complete reference for all configuration options available when creating schemas.

### Options Summary

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `base_uri` | `URI?` | `nil` (auto-generated) | Base URI for resolving relative `$ref` URIs |
| `meta_schema` | `Schema \| String \| Nil` | `"https://json-schema.org/draft/2020-12/schema"` | Meta-schema for validation |
| `vocabulary` | `Hash(String, Bool)?` | `nil` | Custom vocabulary configuration |
| `format` | `Bool?` | `false` (annotation-only) | Enable format validation as assertion |
| `formats` | `Hash(String, FormatValidator)?` | `{}` | Custom format validators |
| `content_encodings` | `Hash(String, ContentEncodingValidator)?` | `{}` | Custom content encoding validators |
| `content_media_types` | `Hash(String, ContentMediaTypeValidator)?` | `{}` | Custom content media type validators |
| `ref_resolver` | `Proc(URI, JSONHash?) \| String \| Nil` | Raises `UnknownRef` | Resolver for external `$ref` URIs |
| `regexp_resolver` | `Proc(String, Regex?) \| String \| Nil` | `"ruby"` | Regex pattern resolver (`"ruby"` or `"ecma"`) |
| `output_format` | `String?` | `"classic"` | Output format: `"flag"`, `"basic"`, or `"classic"` |
| `access_mode` | `String?` | `nil` | Access mode: `"read"` or `"write"` |
| `insert_property_defaults` | `Bool \| Symbol` | `false` | Insert default values (annotation only) |
| `before_property_validation` | `Array(Proc)?` | `[]` | Hooks called before property validation |
| `after_property_validation` | `Array(Proc)?` | `[]` | Hooks called after property validation |

### Detailed Option Descriptions

#### `base_uri`

Sets the base URI used for resolving relative `$ref` references. When loading schemas from a file path, this is automatically set to the file's URI.

```crystal
# Explicitly set base URI
schema = JsonSchemer.schema(
  %q({"$ref": "definitions.json#/User"}),
  base_uri: URI.parse("https://example.com/schemas/")
)
```

#### `meta_schema`

Specifies which meta-schema to use for validating the schema itself. Defaults to Draft 2020-12.

```crystal
# Use OpenAPI 3.1 dialect
schema = JsonSchemer.schema(
  schema_hash,
  meta_schema: "https://spec.openapis.org/oas/3.1/dialect/base"
)

# Use a custom meta-schema
schema = JsonSchemer.schema(
  schema_hash,
  meta_schema: JsonSchemer.draft202012
)
```

#### `format`

Controls whether format validation causes validation failures. Per Draft 2020-12, format is annotation-only by default.

```crystal
# Default: format is annotation-only (doesn't cause failures)
schema = JsonSchemer.schema(%q({"format": "email"}))
schema.valid?(JSON::Any.new("invalid"))  # => true

# Enable format assertion
schema = JsonSchemer.schema(%q({"format": "email"}), format: true)
schema.valid?(JSON::Any.new("invalid"))  # => false
```

#### `formats`

Register custom format validators. Each validator receives the value and format name, returning `true` if valid.

```crystal
schema = JsonSchemer.schema(
  %q({"format": "even-number"}),
  format: true,
  formats: {
    "even-number" => ->(value : JSON::Any, format : String) {
      if num = value.as_i64?
        num.even?
      else
        false
      end
    }
  }
)

schema.valid?(JSON::Any.new(4_i64))   # => true
schema.valid?(JSON::Any.new(3_i64))   # => false
```

#### `content_encodings`

Register custom content encoding validators for the `contentEncoding` keyword. Returns a tuple of `{success, decoded_value}`.

```crystal
schema = JsonSchemer.schema(
  %q({"contentEncoding": "base64"}),
  content_encodings: {
    "base64" => ->(instance : String) {
      begin
        decoded = Base64.decode_string(instance)
        {true, decoded}
      rescue
        {false, nil}
      end
    }
  }
)
```

#### `content_media_types`

Register custom content media type validators for the `contentMediaType` keyword. Returns a tuple of `{success, parsed_value}`.

```crystal
schema = JsonSchemer.schema(
  %q({"contentMediaType": "application/json"}),
  content_media_types: {
    "application/json" => ->(instance : String) {
      begin
        parsed = JSON.parse(instance)
        {true, parsed}
      rescue
        {false, nil}
      end
    }
  }
)
```

#### `ref_resolver`

Resolves external `$ref` URIs to schema documents. Built-in resolvers are available:

```crystal
# Default: raises UnknownRef for any external reference
schema = JsonSchemer.schema(%q({"$ref": "http://example.com/schema.json"}))
# Raises JsonSchemer::UnknownRef when validating

# Use HTTP resolver (fetches schemas over network)
schema = JsonSchemer.schema(
  %q({"$ref": "http://example.com/schema.json"}),
  ref_resolver: JsonSchemer::NET_HTTP_REF_RESOLVER
)

# Use file URI resolver
schema = JsonSchemer.schema(
  %q({"$ref": "file:///path/to/schema.json"}),
  ref_resolver: JsonSchemer::FILE_URI_REF_RESOLVER
)

# Custom resolver with local cache
schemas = {
  "http://example.com/user.json" => {"type" => JSON::Any.new("object")} of String => JSON::Any
}
schema = JsonSchemer.schema(
  %q({"$ref": "http://example.com/user.json"}),
  ref_resolver: ->(uri : URI) { schemas[uri.to_s]? }
)
```

#### `regexp_resolver`

Controls how regex patterns are compiled. Use `"ecma"` for JavaScript-compatible patterns.

```crystal
# Default: Ruby/Crystal PCRE patterns
schema = JsonSchemer.schema(%q({"pattern": "^[a-z]+$"}))

# ECMA-262 (JavaScript) compatible patterns
schema = JsonSchemer.schema(
  %q({"pattern": "^\\p{L}+$"}),
  regexp_resolver: "ecma"
)

# Custom resolver
schema = JsonSchemer.schema(
  schema_hash,
  regexp_resolver: ->(pattern : String) {
    Regex.new(pattern, Regex::Options::IGNORE_CASE)
  }
)
```

#### `output_format`

Controls the structure of validation results.

```crystal
schema = JsonSchemer.schema(%q({"type": "string"}))
data = JSON::Any.new(42_i64)

# "flag" - minimal output, just valid/invalid
result = schema.validate(data, output_format: "flag")
# {"valid" => false}

# "basic" - includes error list with locations
result = schema.validate(data, output_format: "basic")
# {"valid" => false, "errors" => [...]}

# "classic" - detailed errors with pointers (default)
result = schema.validate(data, output_format: "classic")
# {
#   "valid" => false,
#   "errors" => [{
#     "data" => 42,
#     "data_pointer" => "",
#     "schema" => {"type" => "string"},
#     "schema_pointer" => "",
#     "type" => "string",
#     "error" => "value at root is not a string"
#   }]
# }
```

#### `access_mode`

Modifies validation behavior for `readOnly` and `writeOnly` properties.

```crystal
schema_hash = JSON.parse(%q({
  "type": "object",
  "required": ["id", "password"],
  "properties": {
    "id": {"type": "integer", "readOnly": true},
    "password": {"type": "string", "writeOnly": true}
  }
})).as_h

# No access mode: both properties required
schema = JsonSchemer.schema(schema_hash)
schema.valid?(JSON.parse(%q({"id": 1})))              # => false (missing password)
schema.valid?(JSON.parse(%q({"password": "secret"}))) # => false (missing id)

# Read mode: writeOnly properties excluded from required
read_schema = JsonSchemer.schema(schema_hash, access_mode: "read")
read_schema.valid?(JSON.parse(%q({"id": 1})))  # => true

# Write mode: readOnly properties excluded from required  
write_schema = JsonSchemer.schema(schema_hash, access_mode: "write")
write_schema.valid?(JSON.parse(%q({"password": "secret"})))  # => true
```

#### `insert_property_defaults`

Accepts a boolean to enable default value insertion. **Note:** This option is accepted for API compatibility but default insertion is not fully implemented. The `default` keyword works as an annotation only.

```crystal
schema = JsonSchemer.schema(
  %q({
    "properties": {
      "status": {"type": "string", "default": "active"}
    }
  }),
  insert_property_defaults: true
)

# Default values are NOT inserted into the data
data = JSON.parse(%q({}))
schema.validate(data)
data.as_h.has_key?("status")  # => false
```

#### `before_property_validation` / `after_property_validation`

Hooks that are called before and after each property is validated. Useful for logging, transformation, or side effects.

```crystal
before_hooks = [
  ->(data : JSON::Any, property : String, property_schema : JSON::Any, parent : JSON::Any) {
    puts "Validating property: #{property}"
    nil
  }
]

after_hooks = [
  ->(data : JSON::Any, property : String, property_schema : JSON::Any, parent : JSON::Any) {
    puts "Finished validating: #{property}"
    nil
  }
]

schema = JsonSchemer.schema(
  schema_hash,
  before_property_validation: before_hooks,
  after_property_validation: after_hooks
)
```

### Global Configuration

You can set global defaults that apply to all schemas:

```crystal
JsonSchemer.configure do |config|
  config.format = true                           # Enable format validation globally
  config.output_format = "basic"                 # Default output format
  config.regexp_resolver = "ecma"                # Use ECMA patterns by default
  config.ref_resolver = JsonSchemer::NET_HTTP_REF_RESOLVER  # Fetch remote schemas
end

# All schemas now use these defaults
schema = JsonSchemer.schema(%q({"format": "email"}))
schema.valid?(JSON::Any.new("invalid"))  # => false (format validation enabled)
```

## Known Limitations

Based on the JSON Schema Test Suite integration, the following limitations exist:

### Integer Overflow
Crystal's `JSON.parse` uses `Int64` for integers. Schemas with integers exceeding `Int64.MAX` (9,223,372,036,854,775,807) will fail to parse. The `bignum.json` test suite is skipped for this reason.

### Draft Compatibility
Only **Draft 2020-12** is fully implemented. Cross-draft references (e.g., referencing Draft 2019-09 schemas) are not supported.

### ECMA-262 Regex Differences
While ECMA-262 regex patterns are supported via the `regexp_resolver: "ecma"` option, some Unicode semantics differ from PCRE due to Crystal's regex engine being PCRE-based.

### IDN Hostname Validation
Some edge cases in internationalized hostname validation may differ due to UTS#46 vs IDNA2008 implementation differences. Specifically:
- Characters like U+302E (Hangul single dot tone mark)
- Some "Exceptions that are DISALLOWED" characters

### Property Defaults Insertion
The `insert_property_defaults` option is accepted but default value insertion during validation is not fully implemented. The `default` keyword works as an annotation only.

## Development

```bash
# Install dependencies
shards install

# Run all tests
crystal spec

# Run specific test file
crystal spec spec/json_schemer_spec.cr

# Format code
crystal tool format
```

### JSON Schema Test Suite

This project uses the official [JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite) as a git submodule for integration testing:

```bash
# Initialize submodule after cloning
git submodule update --init

# Run test suite integration tests
crystal spec spec/json_schema_test_suite_spec.cr

# Update test suite to latest
git submodule update --remote JSON-Schema-Test-Suite
```

## Contributing

1. Fork it (<https://github.com/cyangle/json_schemer.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- Original Ruby implementation: [json_schemer](https://github.com/davishmcclurg/json_schemer) by David Harsha
- [JSON Schema](https://json-schema.org/) specification

## Contributors

- [Chao Yang](https://github.com/cyangle) - creator and maintainer
