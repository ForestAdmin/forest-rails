require 'httparty'
require 'uri'

module ForestLiana
  class WorkflowExecutionsController < ApplicationController
    # Never forwarded (request or response): hop-by-hop, Host, and body-framing headers.
    # render json: re-serializes the body, so the upstream length/encoding no longer match — and
    # forwarding accept-encoding would defeat Net::HTTP's transparent gzip decompression.
    SKIPPED_HEADERS = %w[
      connection keep-alive transfer-encoding upgrade te trailer
      proxy-authenticate proxy-authorization host
      content-length content-encoding accept-encoding
    ].freeze
    UNSAFE_PATH_FRAGMENTS = ['..', '%2e', '%2E', '\\', "\0"].freeze
    OPEN_TIMEOUT_IN_SECONDS = 2
    REQUEST_TIMEOUT_IN_SECONDS = 120
    UPSTREAM_ERRORS = [
      HTTParty::Error,
      SocketError,
      Errno::ECONNREFUSED,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Timeout::Error,
      OpenSSL::SSL::SSLError
    ].freeze

    # Catch-all: forward any verb/sub-path verbatim to the executor, so a new executor route needs
    # no change here.
    def proxy
      base = ForestLiana.workflow_executor_url
      return head(:not_found) if base.blank?

      normalized_base = base.sub(%r{/+\z}, '')
      path = safe_executor_path
      return head(:not_found) if path.nil?
      return head(:not_found) unless same_origin?(normalized_base, path)

      response = HTTParty.send(
        request.request_method_symbol,
        "#{normalized_base}#{path}",
        headers: forwarded_request_headers,
        query: forwarded_query,
        body: forwarded_body,
        verify: Rails.env.production?,
        # Don't follow redirects: a 3xx Location to an off-origin host would bypass the origin guard.
        follow_redirects: false,
        open_timeout: OPEN_TIMEOUT_IN_SECONDS,
        timeout: REQUEST_TIMEOUT_IN_SECONDS
      )

      forward_response_headers(response)
      render json: response.parsed_response, status: response.code
    rescue *UPSTREAM_ERRORS => e
      Rails.logger.error("[ForestLiana] workflow executor proxy error: #{e.class}: #{e.message}")
      render json: { error: 'workflow_executor_unreachable' }, status: :service_unavailable
    end

    private

    # First-pass rejection of escape attempts; the authoritative origin check is same_origin?.
    def safe_executor_path
      wildcard = params[:path].to_s
      return nil if wildcard.empty? || wildcard.start_with?('/')
      return nil if UNSAFE_PATH_FRAGMENTS.any? { |fragment| wildcard.include?(fragment) }

      "/#{wildcard}"
    end

    # Authoritative SSRF check: forwarding must never leave the executor origin.
    def same_origin?(base, path)
      base_uri = URI.parse(base)
      target = URI.parse("#{base}#{path}")
      target.scheme == base_uri.scheme && target.host == base_uri.host && target.port == base_uri.port
    rescue URI::InvalidURIError
      false
    end

    def forwarded_request_headers
      request.headers.env.each_with_object({}) do |(key, value), acc|
        name = http_header_name(key.to_s)
        next unless name
        next if SKIPPED_HEADERS.include?(name.downcase)
        next if value.nil? || value.to_s.empty?

        acc[name] = value.to_s
      end
    end

    def http_header_name(env_key)
      if env_key.start_with?('HTTP_')
        titleize_header(env_key.delete_prefix('HTTP_'))
      elsif %w[CONTENT_TYPE CONTENT_LENGTH].include?(env_key)
        titleize_header(env_key)
      end
    end

    def titleize_header(rack_name)
      rack_name.split('_').map(&:capitalize).join('-')
    end

    # Strip the routing key (the glob) and Rails internals so only real query params reach the executor.
    def forwarded_query
      params
        .except(:path, :controller, :action, :format)
        .to_unsafe_h
    end

    def forwarded_body
      return nil if request.get? || request.head?

      request.raw_post.presence
    end

    # Forward executor response headers (minus hop-by-hop) so executor-set headers survive the proxy.
    def forward_response_headers(upstream_response)
      upstream_response.headers.each do |name, value|
        next if name.nil? || SKIPPED_HEADERS.include?(name.to_s.downcase)

        forwarded = value.is_a?(Array) ? value.join(', ') : value.to_s
        next if forwarded.empty?

        response.headers[name.to_s] = forwarded
      end
    end
  end
end
