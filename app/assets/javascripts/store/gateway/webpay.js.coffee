# Inspired by spree_gateway's stripe.js.coffee
# Map cc types from webpay to spree
mapCC = (ccType) ->
  if (ccType == 'MasterCard')
    'master'
  else if (ccType == 'Visa')
    'visa'
  else if (ccType == 'American Express')
    'american_express'
  else if (ccType == 'Diners Club')
    'diners_club'
  else if (ccType == 'JCB')
    'jcb'
  else
    ''

$(document).ready ->
  # For errors that happen later.
  Spree.webpayPaymentMethod.prepend("<div id='webpayError' class='errorExplanation' style='display:none'></div>")

  $('.continue').click ->
    $('#webpayError').hide()
    if Spree.webpayPaymentMethod.is(':visible')
      paymentMethodId = Spree.webpayPaymentMethod.prop('id').split("_")[2]
      expiration = $('.cardExpiry:visible').payment('cardExpiryVal')
      params =
        name: $("#name_on_card_#{paymentMethodId}:visible").val()
        number: $('.cardNumber:visible').val().replace(/\s/g, '')
        cvc: $('.cardCode:visible').val()
        exp_month: expiration.month || 0
        exp_year: expiration.year || 0

      WebPay.createToken(params, webpayResponseHandler)
      return false

webpayResponseHandler = (status, response) ->
  if response.error
    $('#webpayError').html(response.error.message).show()
  else
    Spree.webpayPaymentMethod.find('#card_number, #card_expiry, #card_code').prop("disabled" , true)
    Spree.webpayPaymentMethod.find(".ccType").prop("disabled", false)
    Spree.webpayPaymentMethod.find(".ccType").val(mapCC(response.card.type))

    # insert the token into the form so it gets submitted to the server
    paymentMethodId = Spree.webpayPaymentMethod.prop('id').split("_")[2]
    params =
      gateway_payment_profile_id: response.id
      last_digits: response.card.last4
      month: response.card.exp_month
      year: response.card.exp_year
    for k, v of params
      Spree.webpayPaymentMethod.append("<input type='hidden' class='webpayToken' name='payment_source[#{paymentMethodId}][#{k}]' value='#{v}'/>");
    Spree.webpayPaymentMethod.parents("form").get(0).submit();
