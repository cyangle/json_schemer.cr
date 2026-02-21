require "./spec_helper"

describe "Access Mode with allOf" do
  it "filters readOnly properties nested in allOf" do
    schema_hash = JSON.parse(%q({
      "type": "object",
      "required": ["id", "password"],
      "allOf": [
        {
          "properties": {
            "id": {"type": "integer", "readOnly": true},
            "password": {"type": "string", "writeOnly": true}
          }
        }
      ]
    })).as_h
    schema = JsonSchemer.schema(schema_hash, access_mode: "write")
    
    schema.valid?(JSON.parse(%q({"password": "secret"}))).should be_true
  end
end
