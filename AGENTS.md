# AGENTS.md - Agent Guidelines for json_schemer.cr

This is a Crystal port of the Ruby [json_schemer](https://github.com/davishmcclurg/json_schemer) library.
It implements JSON Schema validation according to Draft 2020-12 and OpenAPI 3.1 specifications.

## Build & Test Commands

```bash
# Install dependencies
shards install

# Run all tests
crystal spec

# Run a single test file
crystal spec spec/json_schemer_spec.cr

# Run tests matching a pattern/example name
crystal spec -e "validates type: string"

# Run test at a specific file:line
crystal spec --location spec/json_schemer_spec.cr:32

# Run tests with verbose output
crystal spec -v

# Run with fail-fast (stop on first failure)
crystal spec --fail-fast

# Type-check without running (faster feedback)
crystal build --no-codegen src/json_schemer.cr

# Format code
crystal tool format

# Check format without modifying
crystal tool format --check
```

## Project Structure

```
src/
  json_schemer.cr              # Main entry point, module-level API
  json_schemer/
    schema.cr                  # Core Schema class for validation
    keyword.cr                 # Abstract base class for all keywords
    result.cr                  # Validation result structure
    output.cr                  # Output formatting module
    errors.cr                  # Error classes hierarchy
    configuration.cr           # Configuration options
    format.cr                  # Format validators (email, uri, etc.)
    content.cr                 # Content encoding/media type validators
    ecma_regexp.cr             # ECMA-262 regexp compatibility
    resources.cr               # Schema resource management
    location.cr                # JSON pointer location handling
    cached_resolver.cr         # Cached ref/regexp resolvers
    draft202012/
      vocab/                   # Vocabulary implementations
        core.cr                # $schema, $id, $ref, $anchor, $defs
        validation.cr          # type, enum, const, min/max, etc.
        applicator.cr          # allOf, anyOf, oneOf, if/then/else
        unevaluated.cr         # unevaluatedItems, unevaluatedProperties
        format_annotation.cr   # Format as annotation (default)
        format_assertion.cr    # Format as assertion
        content.cr             # contentEncoding, contentMediaType
        meta_data.cr           # title, description, default, etc.
      vocab.cr                 # Vocabulary registration
      meta.cr                  # Meta schema definitions
    openapi31/                 # OpenAPI 3.1 support
      vocab/base.cr
      vocab.cr
      meta.cr
    openapi.cr                 # OpenAPI document validation
spec/
  spec_helper.cr               # Shared test setup
  json_schemer_spec.cr         # Main test suite
  format_spec.cr               # Format validation tests
  ref_spec.cr                  # $ref resolution tests
  hooks_spec.cr                # Validation hooks tests
  ...
```

## Code Style Guidelines

### Formatting
- **Indentation**: 2 spaces (no tabs)
- **Line endings**: LF (Unix-style)
- **Trailing whitespace**: Remove
- **Final newline**: Required
- Use `crystal tool format` to auto-format

### Imports/Requires
- Standard library requires first (`json`, `uri`, `big`, etc.)
- External dependencies second (`hana`)
- Internal requires in dependency order
- Group requires logically (see `src/json_schemer.cr`)

```crystal
require "json"
require "uri"
require "big"

require "hana"

require "./json_schemer/version"
require "./json_schemer/errors"
# ... etc
```

### Naming Conventions
- **Classes/Modules**: `PascalCase` (e.g., `Schema`, `Keyword`, `DynamicRef`)
- **Methods/Variables**: `snake_case` (e.g., `validate_instance`, `keyword_location`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `VOCABULARIES`, `DEFAULT_REF_RESOLVER`)
- **Type aliases**: `PascalCase` (e.g., `JSONValue`, `JSONHash`)
- **Keyword classes**: Match JSON Schema keyword name in PascalCase
  - `$ref` -> `Ref`
  - `$dynamicAnchor` -> `DynamicAnchor`
  - `additionalProperties` -> `AdditionalProperties`

### Type Annotations
- Always annotate method return types for public methods
- Use union types for nullable values: `Schema | Nil` or `Schema?`
- Use type aliases for complex types:
  ```crystal
  alias JSONValue = Nil | Bool | Int64 | Float64 | String | Array(JSONValue) | Hash(String, JSONValue)
  alias JSONHash = Hash(String, JSON::Any)
  ```

### Error Handling
- Define custom error classes inheriting from `Error < Exception`
- Use descriptive error names: `UnknownRef`, `InvalidRefPointer`, `InvalidEcmaRegexp`
- Raise with context: `raise UnknownRef.new(uri.to_s)`
- Use `not_nil!` sparingly - prefer safe navigation or guards

### Keyword Implementation Pattern
All JSON Schema keywords inherit from `Keyword`:

```crystal
class MyKeyword < Keyword
  # Override parse to process the keyword value during initialization
  def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Regex | Nil
    # Parse and return structured data
    value  # Default: return raw value
  end

  # Override validate to perform validation
  def validate(
    instance : JSON::Any,
    instance_location : Location::Node,
    keyword_location : Location::Node,
    context : Schema::Context
  ) : Result?
    # Perform validation, return result
    valid = # ... your validation logic
    result(instance, instance_location, keyword_location, valid)
  end

  # Override error for custom error messages
  def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
    "value at #{formatted_instance_location} failed validation"
  end
end
```

### Result Creation
Use the `result` method from `Output` module:

```crystal
result(instance, instance_location, keyword_location, valid,
  nested: nested_results,      # Optional: child results
  type: "keyword_name",        # Optional: for classic output
  details: {"key" => value}    # Optional: additional context
)
```

### Test Structure
Tests use Crystal's built-in `spec` framework:

```crystal
require "./spec_helper"

describe "Feature" do
  describe ".method_name" do
    it "does something specific" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string"})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42_i64)).should be_false
    end
  end
end
```

### Common Patterns

**Creating schemas from various inputs**:
```crystal
# From Hash
JsonSchemer.schema({"type" => JSON::Any.new("string")} of String => JSON::Any)

# From JSON string
JsonSchemer.schema(%q({"type": "string"}))

# From parsed JSON
JsonSchemer.schema(JSON.parse(%q({"type": "object"})).as_h)
```

**Type guards in validation**:
```crystal
def validate(instance, instance_location, keyword_location, context)
  unless instance.raw.is_a?(String)
    return result(instance, instance_location, keyword_location, true)
  end
  # String-specific validation...
end
```

**Creating subschemas**:
```crystal
def parse
  result = {} of String => Schema
  value.as_h.each do |key, subschema_value|
    result[key] = subschema(subschema_value, key)
  end
  result
end
```

## Dependencies
- **hana**: JSON Pointer implementation (github: cyangle/hana.cr)
- Crystal >= 1.18.2

## Important Notes

1. **JSON::Any everywhere**: Instance values and schema values are `JSON::Any`
2. **BigDecimal for precision**: Use `BigDecimal` for numeric comparisons (multipleOf)
3. **Location tracking**: Use `Location` module for JSON pointer paths
4. **Lazy initialization**: Use `@field ||= ...` pattern for cached values
5. **Draft 2020-12 default**: Format validation is annotation-only by default
6. **ECMA regexp**: Use `regexp_resolver: "ecma"` for JavaScript-compatible patterns
