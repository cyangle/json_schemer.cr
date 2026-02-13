module JsonSchemer
  module OpenAPI3
    # This module is kept for backward compatibility.
    # All OpenAPI meta-schemas are now loaded dynamically from data/oas files
    # via the OpenAPI3::Schemas module.
    #
    # The schemas are registered in OpenAPI3.schemas by their $id value.

    module Meta
      # Schema resolver that delegates to OpenAPI3.schemas
      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        OpenAPI3.schemas[uri]?
      }
    end
  end
end
