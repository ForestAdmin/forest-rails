require 'httpclient'

class HTTPClient
  alias original_initialize initialize

  def initialize(*args, &block)
    original_initialize(*args, &block)
    # NOTICE: Force use of the default system CA certs (instead of the 6 year old bundled ones).
    @session_manager&.ssl_config&.set_default_paths
  end
end
