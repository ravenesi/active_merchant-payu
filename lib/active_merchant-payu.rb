# -*- encoding : utf-8 -*-
require "active_merchant"
require 'rexml/document'
require 'net/https'
require 'uri'

module ActiveMerchant
  module Billing
    class PayuGateway < Gateway
      BASE_PAYU_URL = "https://www.payu.cz/paygw/"

      self.homepage_url = 'http://www.payu.cz/'
      self.display_name = 'PayU'
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CZ']
      self.default_currency = 'CZK'
      #accepted money format
      self.money_format = :cents


      def initialize(options = {})
        requires!(options, :key1, :key2, :pos_auth_key, :pos_id, :default_desc)
        @options = options
        super
      end

      # Methods suggested to be supported by active_merchant
      # https://github.com/Shopify/active_merchant/blob/master/lib/active_merchant/billing/gateway.rb
      #
      # purchase(money, creditcard, options = {})
      # authorize(money, creditcard, options = {})
      # capture(money, authorization, options = {})
      # void(identification, options = {})
      # credit(money, identification, options = {})
      def authorize(money, credit_card_or_reference, options = {})
        not_yet
      end

      def purchase(money, credit_card_or_reference, options = {})
        not_yet
      end

      def capture(money, authorization, options = {})
        not_yet
      end

      def void(identification, options = {})
        not_yet
      end

      def credit(money, identification, options = {})
        not_yet
      end


      def generate_link(amount, params_array=[], firstname = "", lastname = "", email = "", ip = "", chanel = nil, desc = nil, order_id = nil, language = nil, street = nil, city = nil, postal_code = nil)
        params_to_s = params_array.join('-')
        link = "#{BASE_PAYU_URL}UTF/NewPayment?"
        {
          :first_name => firstname,
          :last_name => lastname,
          :email => email,
          :pos_id => @options[:pos_id],
          :pos_auth_key => @options[:pos_auth_key],
          :amount => (amount*100).to_i,
          :session_id => params_to_s + "-" + Digest::MD5.hexdigest(params_to_s + @options[:key1]).to_s,
          :client_ip => ip,          
          :js => 1,
          :street => street,
          :city => city,
          :postal_code => postal_code,
          :order_id => order_id,
          :language => language || :cs,
          :desc => desc || @options[:default_desc]
        }.each do |k,v|
          link << "#{k}=#{v}&"
        end
        link << "#{:pay_type}=#{chanel}&" if chanel
        URI.encode(link)
      end

      def confirm_by_session_id(session_id)
        params_to_s = session_id.split(/-/)[0..-2].join('-')
        session_id.split('-').last == Digest::MD5.hexdigest(params_to_s + @options[:key1]).to_s
      end

      def get_status(params)

        pos_id = @options[:pos_id]
        key = @options[:key1]
        ts = (Time.now.to_f*1000).to_i
        payment_id = params[:session_id]
        sig = Digest::MD5.hexdigest("#{pos_id}#{payment_id}#{ts}#{key}")
        uri = URI.parse("#{BASE_PAYU_URL}UTF/Payment/get/xml")
        #puts "https://#{uri.host}:#{uri.port}"
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        #puts "https://#{uri.host}:#{uri.port}/#{uri.request_uri}"
        request = Net::HTTP::Post.new(uri.request_uri)
        #puts "data:"
        params_ssl = {'session_id' => payment_id, 'ts' => ts, 'pos_id' => pos_id, 'sig' => sig}
        #puts params_ssl.inspect
        request.set_form_data(params_ssl)        
        raw_response = http.request(request)
        #puts "response:"
        #puts raw_response.inspect
        #puts raw_response.body.inspect        
        response = REXML::Document.new(raw_response.body)
        if !response.blank? and response.root.elements['status'].text == "OK"
          trans = response.root.elements['trans']
          amount = trans.elements['amount'].text.to_f/100
          case trans.elements['status'].text  
                    
          when "1"
            return ["new", amount]
          when "2"
            return ["cancelled", amount]
          when "3"
            return ["rejected", amount]
          when "4"
            return ["started", amount]
          when "5"
            return ["awaiting_collection", amount]
          when "7"
            return ["reject_done", amount]
          when "99"
            return ["ended", amount]
          else
            return false
          end
        else
          return false
        end
      end

      # https://github.com/Shopify/active_merchant/blob/master/lib/active_merchant/billing/gateways/card_stream.rb
      # https://github.com/netguru/siepomaga/blob/master/app/models/payments/platnosci.rb
      def commit(action, parameters)

      end

      private

      def not_yet
        raise 'Not implemented for PayU'
      end

    end
  end
end
