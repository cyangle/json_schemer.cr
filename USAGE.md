# Usage

## Creating Schemas

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

## Basic Validation

```crystal
schema = JsonSchemer.schema(%q({"type": "integer", "minimum": 0, "maximum": 100}))

# Check if valid
schema.valid?(JSON::Any.new(50_i64))   # => true
schema.valid?(JSON::Any.new(150_i64))  # => false
schema.valid?(JSON::Any.new("text"))   # => false
```

## Getting Validation Errors

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

## Output Formats

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

## Type Validation

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

## Numeric Constraints

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

## String Constraints

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

## Array Validation

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

## Object Validation

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

## Combinators

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

## Conditional Validation

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

## References ($ref)

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

## Custom Ref Resolver

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

## Format Validation

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

## Custom Format Validators

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

## Custom Error Messages

Error messages can be customized using the `x-error` keyword.

### `x-error` Keyword

You can override all errors for a schema by providing a string:

```crystal
schema = JsonSchemer.schema(%q({
  "type": "string",
  "x-error": "custom error for schema and all keywords"
}))

result = schema.validate(JSON::Any.new(1_i64), output_format: "basic")
# result["error"] => "custom error for schema and all keywords"
```

Or provide keyword-specific errors using a hash:

```crystal
schema = JsonSchemer.schema(%q({
  "type": "string",
  "minLength": 10,
  "x-error": {
    "minLength": "too short",
    "^": "custom error for schema"
  }
}))

# When minLength fails
result = schema.validate(JSON::Any.new("short"), output_format: "basic")
# result["error"] => "too short"

# When type fails
result = schema.validate(JSON::Any.new(1_i64), output_format: "basic")
# result["error"] => "custom error for schema"
```

### Variable Interpolation

The following variables are available for interpolation in error messages:

- `%{instance}`: The value being validated (e.g., `"foo"`, `42`)
- `%{instanceLocation}`: JSON pointer to the instance (e.g., `/properties/name`)
- `%{formattedInstanceLocation}`: Formatted location (e.g., `` `/properties/name` ``)
- `%{keywordValue}`: The value of the keyword (e.g., `10` for `minLength`)
- `%{keywordLocation}`: JSON pointer to the keyword
- `%{absoluteKeywordLocation}`: Absolute URI to the keyword
- `%{details}`: Detailed error info hash

```crystal
schema = JsonSchemer.schema(%q({
  "type": "integer",
  "minimum": 18,
  "x-error": "Value %{instance} must be at least %{keywordValue}"
}))

schema.validate(JSON::Any.new(10_i64), output_format: "basic")["error"]
# => "Value 10 must be at least 18"
```

## Pretty Error Formatting

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

## Meta-Schema Validation

Validate that a schema itself is valid:

```crystal
# Check if a schema is valid
JsonSchemer.valid_schema?({"type" => JSON::Any.new("string")})  # => true
JsonSchemer.valid_schema?({"type" => JSON::Any.new("invalid")}) # => false

# Get detailed validation errors for invalid schemas
result = JsonSchemer.validate_schema({"type" => JSON::Any.new("invalid")})
puts result["errors"]
```

## OpenAPI 3.1 Support

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

## Access Mode (readOnly/writeOnly)

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

## ECMA-262 Regex Compatibility

```crystal
# Use ECMA-262 regex patterns (JavaScript-compatible)
schema = JsonSchemer.schema(
  %q({"pattern": "^\\\\p{L}+$"}),
  regexp_resolver: "ecma"
)
```
