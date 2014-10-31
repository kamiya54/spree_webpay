require 'webpay'
module Spree

  # not precise notation, but required for Rails convention
  class PaymentMethod::Webpay < PaymentMethod
    preference :secret_key, :string
    preference :publishable_key, :string

    # Meta ================
    def payment_source_class
      CreditCard
    end

    def method_type
      'webpay'
    end

    def payment_profiles_supported?
      true
    end

    def source_required?
      true
    end

    # Copied from spree-core gateway.rb
    def reusable_sources(order)
      if order.completed?
        sources_by_order order
      else
        if order.user_id
          self.credit_cards.where(user_id: order.user_id).with_payment_profile
        else
          []
        end
      end
    end

    def supports?(source)
      @account_info ||= client.account.retrieve
      brand_name =
        case source.brand
        when 'visa' then 'Visa'
        when 'master' then 'MasterCard'
        when 'diners_club' then 'Diners Club'
        when 'american_express' then 'American Express'
        when 'discover' then 'Discover'
        when 'jcb' then 'JCB'
        end
      @account_info.card_types_supported.include?(brand_name)
    end

    # Payment related methods ================
    # Options are ignored unless they are mentioned in parameters list.
    CVC_CODE_TRANSLATOR = {
      'pass' => 'M',
      'fail' => 'N',
      'unchecked' => 'P'
    }

    # Performs an authorization, which reserves the funds on the customer's credit card, but does not
    # charge the card.
    #
    # ==== Parameters
    #
    # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
    # * <tt>paysource</tt> -- The CreditCard or Check details for the transaction.
    def authorize(money, paysource, options = {})
      create_charge(money, paysource, false)
    end

    # Perform a purchase, which is essentially an authorization and capture in a single operation.
    #
    # ==== Parameters
    #
    # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
    # * <tt>paysource</tt> -- The CreditCard or Check details for the transaction.
    def purchase(money, paysource, options = {})
      create_charge(money, paysource, true)
    end

    # Captures the funds from an authorized transaction.
    #
    # ==== Parameters
    #
    # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
    # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
    def capture(money, authorization, options = {})
      wrap_in_active_merchant_response { client.charge.capture(id: authorization, amount: money) }
    end

    # Void a previous transaction
    #
    # ==== Parameters
    #
    # * <tt>authorization</tt> - The authorization returned from the previous authorize request.
    def void(authorization, _source, options = {})
      wrap_in_active_merchant_response { client.charge.refund(authorization) }
    end

    # Refund a transaction.
    #
    # This transaction indicates to the gateway that
    # money should flow from the merchant to the customer.
    #
    # ==== Parameters
    #
    # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value.
    # * <tt>identification</tt> -- The ID of the original transaction against which the refund is being issued.
    def refund(money, _source, identification, options = {})
      wrap_in_active_merchant_response do
        charge = client.charge.retrieve(identification)
        client.charge.refund(id: identification, amount: charge.amount.to_i - charge.amount_refunded.to_i - money)
      end
    end

    def credit(money, source, identification, options = {})
      refund(money, source, identification, options)
    end

    def create_profile(payment)
      return if payment.source.gateway_customer_profile_id.present?

      begin
        customer = client.customer.create(
          email: payment.order.email,
          description: payment.order.name,
          card: payment.source.gateway_payment_profile_id,
          )
        payment.source.update_attributes!({
            gateway_customer_profile_id: customer.id,
            gateway_payment_profile_id: nil
          })
      rescue WebPay::ApiError => e
        payment.send(:gateway_error, e.respond_to?(:data) ? e.data.error.message : e.message)
      end
    end

    private

    def sources_by_order(order)
      source_ids = order.payments.where(source_type: payment_source_class.to_s, payment_method_id: self.id).pluck(:source_id).uniq
      payment_source_class.where(id: source_ids).with_payment_profile
    end

    # In this gateway, what we call 'secret_key' is the 'login'
    def client
      @client ||= WebPay.new(preferred_secret_key)
    end

    def create_charge(money, paysource, capture)
      params = {
        amount: money,
        currency: 'jpy',
        capture: capture,
      }
      if payment_id = paysource.gateway_payment_profile_id.presence
        params[:card] = payment_id
      else
        params[:customer] = paysource.gateway_customer_profile_id.presence
      end
      wrap_in_active_merchant_response { client.charge.create(params) }
    end

    def wrap_in_active_merchant_response(&block)
      begin
        response = block.call
        ActiveMerchant::Billing::Response.new(!response.failure_message,
          response.failure_message || "Transaction approved",
          response.to_h,
          test: !response.livemode,
          authorization: response.id,
          avs_result: nil, # WebPay does not check avs
          cvv_result: CVC_CODE_TRANSLATOR[response.card.cvc_check]
          )
      rescue WebPay::ApiError => e
        ActiveMerchant::Billing::Response.new(false,
          e.respond_to?(:data) ? e.data.error.message : e.message,
          {},
          test: false,
          authorization: e.respond_to?(:data) ? e.data.error.charge : nil,
          avs_result: nil,
          cvv_result: nil
          )
      end
    end
  end
end
