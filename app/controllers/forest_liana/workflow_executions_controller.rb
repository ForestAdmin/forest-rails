require 'httparty'

module ForestLiana
  class WorkflowExecutionsController < ApplicationController
    EXECUTOR_PREFIX = '/runs'.freeze
    # Hop-by-hop headers + those the HTTP client / framework recomputes — never forwarded
    # (request or response side).
    SKIPPED_HEADERS = %w[
      connection keep-alive transfer-encoding upgrade te trailer
      proxy-authenticate proxy-authorization host content-length
    ].freeze
    # Substrings that could let the wildcard escape EXECUTOR_PREFIX (traversal, encoded dots,
    # backslash, null byte).
    UNSAFE_PATH_FRAGMENTS = ['..', '%2e', '%2E', '\\', "\0"].freeze
    OPEN_TIMEOUT_IN_SECONDS = 2
    REQUEST_TIMEOUT_IN_SECONDS = 120
    UPSTREAM_ERRORS = [
      HTTParty::Error,
      SocketError,
      Errno::ECONNREFUSED,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Timeout::Error
    ].freeze

    # Single catch-all: any sub-path/verb under the agent prefix is forwarded to EXECUTOR_PREFIX,
    # so a new executor route needs no change here (PRD-567).
    def proxy
      base = ForestLiana.workflow_executor_url
      return head(:not_found) if base.blank?

      path = safe_executor_path
      return head(:not_found) if path.nil?

      response = HTTParty.send(
        request.request_method_symbol,
        "#{base.sub(%r{/+\z}, '')}#{path}",
        headers: forwarded_request_headers,
        query: forwarded_query,
        body: forwarded_body,
        verify: Rails.env.production?,
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

    # Security boundary: the wildcard can only ever map into EXECUTOR_PREFIX. Returns nil for
    # anything that could escape it, so executor routes outside EXECUTOR_PREFIX stay unreachable
    # through the proxy.
    def safe_executor_path
      wildcard = params[:path].to_s
      return nil if wildcard.empty? || wildcard.start_with?('/')
      return nil if UNSAFE_PATH_FRAGMENTS.any? { |fragment| wildcard.include?(fragment) }

      "#{EXECUTOR_PREFIX}/#{wildcard}"
    end

    # Forward every client header except hop-by-hop / host / content-length, so a new executor
    # header never requires an agent change.
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

    # The glob is the routing key; strip it (and Rails internals) so only real query params reach
    # the executor.
    def forwarded_query
      params
        .except(:path, :controller, :action, :format)
        .to_unsafe_h
    end

    def forwarded_body
      return nil if request.get? || request.head?

      request.raw_post.presence
    end

    # Forward every executor response header except hop-by-hop ones, so new executor headers never
    # require an agent change (PRD-567: zero breaking, the agent stays a transparent proxy).
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
