module JsonSchemer
  module OpenAPI3
    module Document
      # Schema resolver that delegates to OpenAPI3.schemas
      # The schema-base files from data/oas have strict const values for jsonSchemaDialect
      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        OpenAPI3.resolve_schema(uri)
      }
    end
  end
end
