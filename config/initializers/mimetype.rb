api_mime_types = %W(
  application/vnd.api+json
  text/x-json
  application/json
)

api_mime_types = %w(
  text/x-json
  application/jsonrequest
  application/vnd.api+json
)

Mime::Type.unregister :json
Mime::Type.register 'application/json', :json, api_mime_types
