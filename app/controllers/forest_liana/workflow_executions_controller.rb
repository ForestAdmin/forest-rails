require 'httparty'

module ForestLiana
  class WorkflowExecutionsController < ApplicationController
    FORWARDED_HEADERS = %w[Authorization Cookie].freeze
    UPSTREAM_ERRORS = [
      HTTParty::Error,
      SocketError,
      Errno::ECONNREFUSED,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Timeout::Error
    ].freeze

    def show
      forward_to_executor(method: :get, suffix: '')
    end

    def trigger
      forward_to_executor(method: :post, suffix: '/trigger')
    end

    private

    def forward_to_executor(method:, suffix:)
      base = ForestLiana.workflow_executor_url
      if base.blank?
        head :not_found
        return
      end

      url = "#{base.sub(%r{/+\z}, '')}/runs/#{params[:run_id]}#{suffix}"
      response = HTTParty.send(
        method,
        url,
        headers: forwarded_headers,
        query: forwarded_query,
        body: forwarded_body(method),
        verify: Rails.env.production?
      )

      render json: response.parsed_response, status: response.code
    rescue *UPSTREAM_ERRORS => e
      Rails.logger.error("[ForestLiana] workflow executor proxy error: #{e.class}: #{e.message}")
      render json: { error: 'workflow_executor_unreachable' }, status: :service_unavailable
    end

    def forwarded_headers
      base = { 'Content-Type' => 'application/json' }
      FORWARDED_HEADERS.each_with_object(base) do |name, acc|
        value = request.headers[name]
        acc[name] = value if value.present?
      end
    end

    def forwarded_query
      params
        .except(:run_id, :controller, :action, :format)
        .to_unsafe_h
    end

    def forwarded_body(method)
      return nil if method == :get

      raw = request.raw_post
      raw.presence
    end
  end
end
