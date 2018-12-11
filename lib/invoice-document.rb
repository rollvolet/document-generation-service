# coding: utf-8
require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class InvoiceDocument

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end

    def generate(path, data, language)
      coder = HTMLEntities.new

      template_path = select_template(data, language)
      html = File.open(template_path, 'rb') { |file| file.read }

      invoice_number = generate_invoice_number(data)
      html.sub! '<!-- {{NUMBER}} -->', invoice_number  
      
      invoice_date = generate_invoice_date(data)
      html.sub! '<!-- {{DATE}} -->', invoice_date  

      customer_number = data['customer']['number'].to_s
      html.sub! '<!-- {{CUSTOMER_NUMBER}} -->', customer_number  
      
      own_reference = coder.encode(generate_own_reference(data), :named)
      html.sub! '<!-- {{OWN_REFERENCE}} -->', own_reference  

      ext_reference = coder.encode(generate_ext_reference(data), :named)
      html.sub! '<!-- {{EXT_REFERENCE}} -->', ext_reference

      # TODO must be the embedded building instead of the referenced
      building = coder.encode(generate_building(data), :named)
      html.sub! '<!-- {{BUILDING}} -->', building

      # TODO must be the embedded customer instead of the referenced      
      addresslines = coder.encode(generate_addresslines(data), :named)
      html.sub! '<!-- {{ADDRESSLINES}} -->', addresslines

      # TODO must be the embedded customer instead of the referenced
      contactlines = coder.encode(generate_contactlines(data), :named)
      html.sub! '<!-- {{CONTACTLINES}} -->', contactlines

      pricing = generate_pricing(data)
      html.sub! '<!-- {{INVOICELINES}} -->', pricing[:invoicelines]
      html.sub! '<!-- {{TOTAL_NET_PRICE}} -->', format_decimal(pricing[:total_net_price])
      html.sub! '<!-- {{VAT_RATE}} -->', format_vat_rate(pricing[:vat_rate])
      html.sub! '<!-- {{TOTAL_VAT}} -->', format_decimal(pricing[:total_vat])
      html.sub! '<!-- {{TOTAL_PAID}} -->', format_decimal(pricing[:total_paid])
      html.sub! '<!-- {{TOTAL_GROSS_PRICE}} -->', format_decimal(pricing[:total_gross_price])

      generate_certificate_notification(data)

      html.sub! '<!-- {{INLINE_CSS}} -->', @inline_css      

      write_to_pdf(path, html, '/templates/offerte-footer.html')
    end

    def select_template(data, language)
      if language == 'FRA'
        ENV['INVOICE_TEMPLATE_FR'] || '/templates/factuur-fr.html'
      else
        ENV['INVOICE_TEMPLATE_NL'] || '/templates/factuur-nl.html'
      end
    end


    def generate_own_reference(data)
      order = data['order']
      if order
        offer = order['offer']
        own_reference = "<b>AD #{order['requestNumber']}</b>"
        own_reference += " <b>#{data['visit']['visitor']}</b>" if data['visit']
        own_reference += "<br><span class='note'>#{offer['number']} #{offer['documentVersion']}</span>"
        own_reference
      else
        hide_element('references--own_reference')
      end
    end

    def generate_pricing(data)
      invoicelines = []
      prices = []

      if data['order']
        # TODO we assume all ordered offerlines have the same VAT rate as the invoice
        data['order']['offer']['offerlines'].find_all { |l| l['isOrdered'] }.each do |offerline|
          prices << offerline['amount']
          line = "<div class='invoiceline'>"
          line += "  <div class='col col-1'>#{offerline['description']}</div>"
          line += "  <div class='col col-2'>&euro; #{format_decimal(offerline['amount'])}</div>"
          line += "</div>"
          invoicelines << line
        end
      end

      if data['supplements']
        data['supplements'].each do |supplement|
          nb_of_pieces = supplement['nbOfPieces'] || 1.0
          line_price = nb_of_pieces * supplement['amount']

          prices << line_price
          line = "<div class='invoiceline'>"
          line += "  <div class='col col-1'>#{nb_of_pieces} x #{supplement['description']}</div>"
          line += "  <div class='col col-2'>&euro; #{format_decimal(line_price)}</div>"
          line += "</div>"
          invoicelines << line
        end
      end

      deposits = []
      if data['deposits']
        deposits = data['deposits'].map { |d| d['amount'] || 0 }
      end

      deposit_invoices = []
      if data['depositInvoices']
        deposit_invoices = data['depositInvoices'].map { |d| d['totalAmount'] || 0}
      end

      total_net_price = prices.inject(:+) || 0
      vat_rate = data['vatRate']['rate']
      total_vat = total_net_price * vat_rate / 100
      total_deposits = deposits.inject(:+) || 0
      total_deposit_invoices = deposit_invoices.inject(:+) || 0
      total_gross_price = total_net_price + total_vat - total_deposits - total_deposit_invoices

      hide_element('priceline-deposit') if (total_deposits == 0)
      hide_element('priceline-deposit-invoice') if (total_deposit_invoices == 0)

      {
        invoicelines: invoicelines.join,
        total_net_price: total_net_price,
        vat_rate: vat_rate,
        total_vat: total_vat,
        total_deposits: total_deposits,
        total_deposit_invoices: total_deposit_invoices,
        total_gross_price: total_gross_price
      }
    end

    def generate_certificate_notification(data)
      hide_element('certificate-notification') if not data['certificateRequired'] or data['certificateReceived']
    end
  end
end
