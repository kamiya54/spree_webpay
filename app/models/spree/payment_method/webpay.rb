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

    # TODO: support it
    def payment_profiles_supported?
      false
    end

    def source_required?
      true
    end

    # TODO: implement using WebPay Customer
    def reusable_sources(order)
      super
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
    end

    # Void a previous transaction
    #
    # ==== Parameters
    #
    # * <tt>authorization</tt> - The authorization returned from the previous authorize request.
    def void(authorization, options = {})
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
    def refund(money, identification, options = {})

    end

    def credit(money, identification, options = {})
      refund(money, identification, options)
    end

    private

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
      params[:card] = paysource.gateway_payment_profile_id
      begin
        response = client.charge.create(params)
        ActiveMerchant::Billing::Response.new(!response.failure_message,
          "Transaction approved",
          response.to_h,
          :test => !!response.livemode,
          :authorization => response.id,
          :avs_result => nil, # WebPay does not check avs
          :cvv_result => CVC_CODE_TRANSLATOR[response.card.cvc_check]
          )
      rescue WebPay::ApiError => e
        ActiveMerchant::Billing::Response.new(false,
          e.respond_to?(:data) ? e.data.error.message : e.message,
          {},
          :test => false,
          :authorization => e.respond_to?(:data) ? e.data.error.charge : nil,
          :avs_result => nil,
          :cvv_result => nil
          )
      end
    end
  end
end
