module ForestLiana
  class StripePaymentsGetter
    attr_accessor :records

    def initialize(secret_key)
      Stripe.api_key = secret_key
    end

    def perform
      @records = Stripe::Charge.all(limit: 10).data.map do |d|
        d.created = Time.at(d.created).to_datetime
        d.amount /= 100

        d
      end
    end
  end
end
