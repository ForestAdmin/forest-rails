require 'rack/cors'

use Rack::Lint
use Rack::Cors do
  allow do
    origins 'localhost:3000',
            '127.0.0.1:3000'

    resource '/', headers: :any, methods: :any
    resource '/options', methods: :options
  end
end
