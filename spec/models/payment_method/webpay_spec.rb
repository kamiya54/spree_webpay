require 'spec_helper'
require 'webpay/mock'

describe Spree::PaymentMethod::Webpay do
  subject(:payment_method) { described_class.new() }
  before do
    payment_method.preferences = { secret_key: 'test_secret_xxx' }
  end
  let(:empty_avs_result) { {"code"=>nil, "message"=>nil, "street_match"=>nil, "postal_match"=>nil} }
  let(:match_cvv_result) { {"code"=>"M", "message"=>"Match"} }
  let(:empty_cvv_result) { {"code"=>nil, "message"=>nil} }

  describe '#supports?' do
    before do
      webpay_stub(:account, :retrieve, overrides: { card_types_supported: ['Visa', 'MasterCard'] })
    end

    def stub_source(brand)
      double('Source', brand: brand)
    end

    it 'should be true when the source brand is visa' do
      expect(payment_method.supports?(stub_source('visa'))).to eq true
    end

    it 'should be true when the source brand is jcb' do
      expect(payment_method.supports?(stub_source('jcb'))).to eq false
    end
  end

  describe '#authorize' do
    let(:mock_card) { double('CreditCard', gateway_payment_profile_id: 'tok_fromspreeform') }
    let(:params) { {
        amount: 1500,
        currency: 'jpy',
        card: mock_card.gateway_payment_profile_id,
        capture: false,
      }}

    it 'should request as expected' do
      mock_response = webpay_stub(:charges, :create, params: params)
      payment_method.authorize(1500, mock_card)
      assert_requested(:post, "https://api.webpay.jp/v1/charges", body: JSON.dump(params))
    end

    it 'should return succeeded ActiveMerchant::Billing::Response for correct transaction' do
      mock_response = webpay_stub(:charges, :create, params: params)
      response = payment_method.authorize(1500, mock_card)
      expect(response).to be_success
      expect(response.message).to eq 'Transaction approved'
      expect(response.test).to eq true
      expect(response.authorization).to eq mock_response['id']
      expect(response.avs_result).to eq empty_avs_result
      expect(response.cvv_result).to eq match_cvv_result
    end

    it 'should return failed ActiveMerchant::Billing::Response for errors' do
      mock_response = webpay_stub(:charges, :create, params: params, error: :card_error)
      response = payment_method.authorize(1500, mock_card)
      expect(response).not_to be_success
      expect(response.message).to eq 'This card cannot be used.'
      expect(response.test).to eq false
      expect(response.authorization).to eq nil
      expect(response.avs_result).to eq empty_avs_result
      expect(response.cvv_result).to eq empty_cvv_result
    end

    it 'should return failed ActiveMerchant::Billing::Response for response with failure_message' do
      mock_response = webpay_stub(:charges, :create, params: params, overrides: { failure_message: 'Service unavailable' })
      response = payment_method.authorize(1500, mock_card)
      expect(response).not_to be_success
      expect(response.message).to eq 'Service unavailable'
      expect(response.test).to eq true
      expect(response.authorization).to eq mock_response['id']
      expect(response.avs_result).to eq empty_avs_result
      expect(response.cvv_result).to eq match_cvv_result
    end
  end

  describe '#purchase' do
    let(:mock_card) { double('CreditCard', gateway_payment_profile_id: 'tok_fromspreeform') }
    let(:params) { {
        amount: 1500,
        currency: 'jpy',
        card: mock_card.gateway_payment_profile_id,
        capture: true,
      }}

    it 'should request as expected' do
      mock_response = webpay_stub(:charges, :create, params: params)
      payment_method.purchase(1500, mock_card)
      assert_requested(:post, "https://api.webpay.jp/v1/charges", body: JSON.dump(params))
    end

    it 'should return succeeded ActiveMerchant::Billing::Response for correct transaction' do
      mock_response = webpay_stub(:charges, :create, params: params)
      response = payment_method.purchase(1500, mock_card)
      expect(response).to be_success
      expect(response.message).to eq 'Transaction approved'
      expect(response.test).to eq true
      expect(response.authorization).to eq mock_response['id']
      expect(response.avs_result).to eq empty_avs_result
      expect(response.cvv_result).to eq match_cvv_result
    end

    # other cases are covered by #authorize
  end

  describe '#capture' do
    let(:charge_id) { 'ch_authorizedcharge' }
    let(:params) { { id: charge_id, amount: 1300 } }

    it 'should capture existing charge with given amount' do
      webpay_stub(:charges, :capture, params: params)
      payment_method.capture(1300, charge_id)
      assert_requested(:post, "https://api.webpay.jp/v1/charges/#{charge_id}/capture", body: JSON.dump(amount: 1300))
    end

    it 'should return success ActiveMerchant::Billing::Response' do
      webpay_stub(:charges, :capture, params: params)
      response = payment_method.capture(1300, charge_id)
      expect(response).to be_success
    end

    it 'should return failed ActiveMerchant::Billing::Response for errors' do
      webpay_stub(:charges, :capture, params: params, error: :bad_request)
      response = payment_method.capture(1300, charge_id)
      expect(response).not_to be_success
    end
  end

  describe '#void' do
    let(:charge_id) { 'ch_authorizedcharge' }
    let(:params) { { id: charge_id } }

    it 'should capture existing charge with given amount' do
      webpay_stub(:charges, :refund, params: params)
      payment_method.void(charge_id)
      assert_requested(:post, "https://api.webpay.jp/v1/charges/#{charge_id}/refund", body: '{}')
    end

    it 'should return success ActiveMerchant::Billing::Response' do
      webpay_stub(:charges, :refund, params: params)
      response = payment_method.void(charge_id)
      expect(response).to be_success
    end

    it 'should return failed ActiveMerchant::Billing::Response for errors' do
      webpay_stub(:charges, :refund, params: params, error: :bad_request)
      response = payment_method.void(charge_id)
      expect(response).not_to be_success
    end
  end

  describe '#refund' do
    let(:charge_id) { 'ch_captured' }
    let!(:charge) { webpay_stub(:charges, :retrieve, params: { id: charge_id }, overrides: { amount: 1500, refunded: false, amount_refunded: 100 }) }
    let(:params) { { id: charge_id, amount: 400 } }

    it 'should capture existing charge with given amount' do
      webpay_stub(:charges, :refund, params: params)
      payment_method.refund(1000, charge_id)
      assert_requested(:post, "https://api.webpay.jp/v1/charges/#{charge_id}/refund", body: JSON.dump(amount: 400))
    end

    it 'should return success ActiveMerchant::Billing::Response' do
      webpay_stub(:charges, :refund, params: params)
      response = payment_method.refund(1000, charge_id)
      expect(response).to be_success
    end

    it 'should return failed ActiveMerchant::Billing::Response for errors in retrieve' do
      webpay_stub(:charges, :retrieve, params: { id: charge_id }, error: :not_found)
      response = payment_method.refund(1000, charge_id)
      expect(response).not_to be_success
      expect(response.message).to eq 'No such charge: ch_bBM4IJ0XF2VIch8'
    end

    it 'should return failed ActiveMerchant::Billing::Response for errors in refund' do
      webpay_stub(:charges, :refund, params: params, error: :bad_request)
      response = payment_method.refund(1000, charge_id)
      expect(response).not_to be_success
      expect(response.message).to eq "can't save charge: Amount can't be blank" # test error message
    end
  end
end
