require 'webpay'
module Spree

  # not precise notation, but required for Rails convention
  class PaymentMethod::Webpay < PaymentMethod
    preference :secret_key, :string
    preference :publishable_key, :string

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

    # Payment related methods called from Spree core modules.
    # Options are ignored unless they are mentioned in parameters list.

    # Performs an authorization, which reserves the funds on the customer's credit card, but does not
    # charge the card.
    #
    # ==== Parameters
    #
    # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
    # * <tt>paysource</tt> -- The CreditCard or Check details for the transaction.
    def authorize(money, paysource, options = {})
    end

    # Perform a purchase, which is essentially an authorization and capture in a single operation.
    #
    # ==== Parameters
    #
    # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
    # * <tt>paysource</tt> -- The CreditCard or Check details for the transaction.
    def purchase(money, paysource, options = {})
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
  end
end
