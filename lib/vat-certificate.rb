# coding: utf-8
require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class VatCertificate

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end
    
    def generate(path, data, language)
      coder = HTMLEntities.new

      template_path = select_template(data, language)
      html = File.open(template_path, 'rb') { |file| file.read }
      
      customer_name = generate_customer_name(data)
      html.sub! '<!-- {{CUSTOMER_NAME}} -->', customer_name  

      customer_address = coder.encode(generate_customer_address(data), :named)
      html.sub! '<!-- {{CUSTOMER_ADDRESS}} -->', customer_address

      building_address = coder.encode(generate_building_address(data), :named)
      html.sub! '<!-- {{BUILDING_ADDRESS}} -->', building_address

      invoice_number = generate_invoice_number(data)
      html.sub! '<!-- {{INVOICE_NUMBER}} -->', invoice_number  
      
      invoice_date = generate_invoice_date(data)
      html.sub! '<!-- {{INVOICE_DATE}} -->', invoice_date  
      
      html.sub! '<!-- {{INLINE_CSS}} -->', @inline_css      

      write_to_pdf(path, html)
    end

    def select_template(data, language)
      if language == 'FRA'
        ENV['CERTIFICATE_TEMPLATE_FR'] || '/templates/attest-fr.html'
      else
        ENV['CERTIFICATE_TEMPLATE_NL'] || '/templates/attest-nl.html'
      end
    end

    def generate_customer_name(data)
      customer = data['customer']

      name = ''
      name += " #{customer['prefix']}" if customer['prefix'] and customer['printPrefix']
      name += " #{customer['name']}" if customer['name']
      name += " #{customer['suffix']}" if customer['suffix'] and customer['printSuffix']
      name
    end

    def generate_customer_address(data)
      customer = data['customer']
      [ customer['address1'],
        customer['address2'],
        customer['address3'],
        "#{customer['postalCode']} #{customer['city']}"
      ].find_all { |a| a }.join('<br>')
    end

    def generate_building_address(data)
      building = data['building']
      
      if building
        [ building['address1'],
          building['address2'],
          building['address3'],
          "#{building['postalCode']} #{building['city']}"
        ].find_all { |a| a }.join('<br>')
      else
        generate_customer_address(data)
      end
    end
  end
end
