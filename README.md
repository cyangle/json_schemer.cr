# json_schemer.cr

A Crystal port of the Ruby [json_schemer](https://github.com/davishmcclurg/json_schemer) library for validating JSON documents against [JSON Schema](https://json-schema.org/).

[![Crystal Version](https://img.shields.io/badge/crystal-%3E%3D1.19-blue.svg)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> [!CAUTION]
> **Experimental Implementation:** This project is almost 100% vibe-coded.
> While it passes an extensive suite of unit and third-party integration tests,
> the internal logic may not follow traditional patterns. Use at your own risk.

## Features

- **JSON Schema Draft 2020-12** compliant
- **OpenAPI 3.1 and 3.2** schema validation support
- Multiple output formats: `flag`, `basic`, `classic`
- Custom format validators
- Custom keyword validators or **Custom keyword classes**
- Custom ref resolvers (file, HTTP, custom)
- ECMA-262 compatible regex patterns
- `$ref`, `$anchor`, `$dynamicRef` / `$dynamicAnchor` support
- Complete vocabulary implementations
- `contentSchema` support for validating content of string-encoded data
- Custom error messages with `x-error`

## Installation

**Prerequisites:** This shard relies on `simpleidn` for full IDN hostname validation, which requires **ICU** (International Components for Unicode).

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

See the full [Usage Guide](USAGE.md) for detailed examples including:

- Creating schemas from JSON strings, hashes, or files
- Basic and advanced validation
- Output formats (`flag`, `basic`, `classic`)
- Type, numeric, string, array, and object validation
- Schema combinators (`allOf`, `anyOf`, `oneOf`, `not`)
- Conditional validation (`if`/`then`/`else`)
- References (`$ref`, `$anchor`, `$dynamicRef`)
- Format validation and custom format validators
- Custom keyword validators
- OpenAPI 3.1 support
- OpenAPI 3.2 support
- Access modes (`readOnly`/`writeOnly`)
- ECMA-262 regex compatibility

## Advanced & Optional Features

### 1. IDN Support (Syntax Validation)

By default, `simpleidn` support is **disabled** to avoid a hard dependency on `libicu`.
- `hostname` and `email` format validation uses a naive implementation (regex/length checks only; no strict Punycode/IDN validation).
- `idn-hostname` and `idn-email` format validation is disabled (logs a warning and always returns false).

To enable strict IDN syntax validation (requires `libicu` installed on the system):
1. Install ICU development headers:
   - Ubuntu/Debian: `sudo apt-get install libicu-dev`
   - macOS: `brew install icu4c`
   - Alpine: `apk add icu-dev`
2. Compile your project with the `-Dwith_simpleidn` flag:
   ```bash
   crystal build -Dwith_simpleidn src/your_app.cr
   ```

### 2. DNS Hostname Validation (Existence Check)

While `simpleidn` validates the **syntax** of a hostname, you can also use `DnsHostnameValidator` to check if the domain actually **exists** in the DNS.

```crystal
require "json_schemer"

# Create a validator with DNS resolution enabled
dns_validator = JsonSchemer::Format::DnsHostnameValidator.new(ttl: 10.minutes)

schema = JsonSchemer.schema(
  %q({"format": "hostname"}),
  format: true,
  formats: {"hostname" => dns_validator}
)

schema.valid?(JSON::Any.new("google.com"))  # => true
schema.valid?(JSON::Any.new("non-existent-domain-12345.com"))  # => false
```

> [!IMPORTANT]
> **Blocking DNS Lookups:** By default, Crystal's `Socket::Addrinfo` performs **blocking** DNS lookups.
> For production environments, it is highly recommended to use the [**spider-gazelle/dns**](https://github.com/spider-gazelle/dns) shard for non-blocking resolution.
>
> Add `dns` to your `shard.yml` and require the monkey-patch:
> ```crystal
> require "dns/ext/addrinfo"
> ```

### 3. Chaining Multiple Validators

Since the `formats` option only accepts one validator per format name, you can chain multiple checks by creating a wrapper validator that calls them in sequence.

For example, to combine the built-in syntax validation with a custom internal domain check:

```crystal
# Define a chained validator
chained_validator = ->(value : JSON::Any, format : String) {
  # 1. First, call the built-in syntax validator
  return false unless JsonSchemer::Format::HOSTNAME.call(value, format)

  # 2. Then, apply custom logic (e.g., must be a .com domain)
  if hostname = value.as_s?
    hostname.ends_with?(".com")
  else
    true # Let other keywords handle type validation
  end
}

schema = JsonSchemer.schema(
  %q({"format": "hostname"}),
  format: true,
  formats: {"hostname" => chained_validator}
)
```

The `DnsHostnameValidator` already chains syntax validation automatically before performing DNS lookups. If you want to add even more logic on top of it:

```crystal
dns_validator = JsonSchemer::Format::DnsHostnameValidator.new

combined = ->(value : JSON::Any, format : String) {
  # Chain: Syntax -> DNS Lookup -> Custom Logic
  dns_validator.call(value, format) && value.as_s.starts_with?("api-")
}

schema = JsonSchemer.schema(..., formats: {"hostname" => combined})
```

### 4. Class-Based Custom Keywords

For complex custom validation logic that requires parsing schema values (like checking bounds or configuration options), you can define a custom keyword class inheriting from `JsonSchemer::Keyword`.

This is more powerful than the simple proc-based `keywords` option as it allows you to pre-process the schema value during initialization.

```crystal
class MoneyKeyword < JsonSchemer::Keyword
  def validate(instance, instance_location, keyword_location, context)
    # ... validation logic ...
    nil
  end
end

# 1. Register keyword in a custom vocabulary
JsonSchemer::VOCABULARIES["https://example.com/vocab/money"] = {
  "money" => MoneyKeyword.as(JsonSchemer::Keyword.class)
}
JsonSchemer::VOCABULARY_ORDER["https://example.com/vocab/money"] = 100

# 2. Define a meta-schema using this vocabulary
meta_schema = {
  "$id" => "https://example.com/meta",
  "$schema" => "https://json-schema.org/draft/2020-12/schema",
  "$vocabulary" => {
    "https://json-schema.org/draft/2020-12/vocab/core" => true,
    "https://json-schema.org/draft/2020-12/vocab/applicator" => true,
    "https://json-schema.org/draft/2020-12/vocab/validation" => true,
    "https://json-schema.org/draft/2020-12/vocab/meta-data" => true,
    "https://json-schema.org/draft/2020-12/vocab/format-annotation" => true,
    "https://json-schema.org/draft/2020-12/vocab/content" => true,
    "https://json-schema.org/draft/2020-12/vocab/unevaluated" => true,
    "https://example.com/vocab/money" => true
  }
}

# 3. Use the meta-schema in your schema
schema = JsonSchemer.schema(
  %q({
    "$schema": "https://example.com/meta",
    "money": "100.00"
  }),
  ref_resolver: ->(uri : URI) {
    uri.to_s == "https://example.com/meta" ? meta_schema : nil
  }
)
```

See [USAGE.md](USAGE.md#class-based-custom-keywords) for a complete example including parsing configuration options.

## Configuration Reference

This section provides a complete reference for all configuration options available when creating schemas.

### Options Summary

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `base_uri` | `URI` | `nil` (auto-generated) | Base URI for resolving relative `$ref` URIs |
| `meta_schema` | `Schema \| String` | `"https://json-schema.org/draft/2020-12/schema"` | Meta-schema for validation |
| `vocabulary` | `Hash(String, Bool)?` | `nil` | Custom vocabulary configuration |
| `format` | `Bool` | `true` | Enable format validation as assertion |
| `formats` | `Hash(String, FormatValidator)` | `{}` | Custom format validators |
| `content_encodings` | `Hash(String, ContentEncodingValidator)` | `{}` | Custom content encoding validators |
| `content_media_types` | `Hash(String, ContentMediaTypeValidator)` | `{}` | Custom content media type validators |
| `keywords` | `Hash(String, Proc)` | `{}` | Custom keyword validators |
| `ref_resolver` | `Proc(URI, JSONHash?) \| String` | Raises `UnknownRef` | Resolver for external `$ref` URIs |
| `regexp_resolver` | `Proc(String, Regex?) \| String` | `"ruby"` | Regex pattern resolver (`"ruby"` or `"ecma"`) |
| `output_format` | `String` | `"classic"` | Output format: `"flag"`, `"basic"`, or `"classic"` |
| `access_mode` | `String?` | `nil` | Access mode: `"read"` or `"write"` |
| `insert_property_defaults` | `Bool` | `false` | Insert default values (annotation only) |
| `property_default_resolver` | `Proc?` | `nil` | Custom resolver for property defaults |
| `resolve_enumerators` | `Bool` | `false` | Whether to resolve enumerators during validation |

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
  meta_schema: "https://spec.openapis.org/oas/3.1/schema/2025-09-15"
)

# Use a custom meta-schema
schema = JsonSchemer.schema(
  schema_hash,
  meta_schema: JsonSchemer.draft202012
)
```

#### `format`

Controls whether format validation causes validation failures. The library enables format validation by default (`true`). To follow Draft 2020-12 strict annotation-only behavior, set this to `false`.

```crystal
# Default: format validation is enabled
schema = JsonSchemer.schema(%q({"format": "email"}))
schema.valid?(JSON::Any.new("invalid"))  # => false

# Disable format assertion (annotation-only)
schema = JsonSchemer.schema(%q({"format": "email"}), format: false)
schema.valid?(JSON::Any.new("invalid"))  # => true
```

#### `formats`

Register custom format validators. Each validator receives the value and format name, returning `true` if valid.

> [!WARNING]
> **Unhandled Exceptions:** Exceptions raised within custom format validators are **not caught** by the library and will propagate up to the caller. You should handle exceptions within your validator proc if you want to prevent them from crashing the validation process.

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

> [!NOTE]
> **Standard Meta-Schemas:** You do not need to resolve standard JSON Schema meta-schemas (e.g., `https://json-schema.org/draft/2020-12/schema`) or OpenAPI dialect schemas in your custom resolver. The library automatically falls back to built-in definitions if your resolver returns `nil`.

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

Accepts a boolean to enable default value insertion. Default values are inserted into the validated instance.

```crystal
schema = JsonSchemer.schema(
  %q({
    "properties": {
      "status": {"type": "string", "default": "active"}
    }
  }),
  insert_property_defaults: true
)

# Default values are inserted into the data
data = JSON.parse(%q({}))
schema.validate(data)
data.as_h["status"].as_s  # => "active"
```

#### `keywords`

Register custom keyword validators. Each validator receives the instance, schema value, and JSON pointer, returning `true` if valid or an array of error strings if invalid.

```crystal
schema = JsonSchemer.schema(
  %q({
    "type": "string",
    "x-must-be-uppercase": true
  }),
  keywords: {
    "x-must-be-uppercase" => ->(instance : JSON::Any, schema : JSON::Any, pointer : String) {
      if str = instance.as_s?
        if str == str.upcase
          true
        else
          ["value must be uppercase"] of String
        end
      else
        true  # Non-strings pass this check
      end
    }
  }
)

schema.valid?(JSON::Any.new("HELLO"))   # => true
schema.valid?(JSON::Any.new("hello"))   # => false
```

#### `property_default_resolver`

Custom resolver for property defaults. This advanced option allows control over how default values are resolved. **Note:** This option is accepted for API compatibility but is not fully implemented.

#### `resolve_enumerators`

When set to `true`, allows resolving enumerators during validation. Defaults to `false`. **Note:** This option is accepted for API compatibility but behavior may be limited.


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

### Other API Compatibility Options
The `property_default_resolver` and `resolve_enumerators` options are accepted for API compatibility but may have limited functionality.

## Development

```bash
# Install dependencies
shards install

# Run all tests (default: no simpleidn)
crystal spec

# Run all tests with simpleidn enabled (requires ICU)
crystal spec -Dwith_simpleidn

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
