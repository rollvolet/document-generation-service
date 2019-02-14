# coding: utf-8
require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class DepositInvoiceDocument

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end

    def generate(path, data, language)
      coder = HTMLEntities.new

      template_path = select_template(data, language)
      html = File.open(template_path, 'rb') { |file| file.read }

      invoice_number = generate_invoice_number(data)
      html.gsub! '<!-- {{NUMBER}} -->', invoice_number

      invoice_date = generate_invoice_date(data)
      html.gsub! '<!-- {{DATE}} -->', invoice_date

      customer_number = data['customer']['number'].to_s
      html.gsub! '<!-- {{CUSTOMER_NUMBER}} -->', customer_number

      own_reference = coder.encode(generate_own_reference(data), :named)
      html.gsub! '<!-- {{OWN_REFERENCE}} -->', own_reference

      ext_reference = coder.encode(generate_ext_reference(data), :named)
      html.gsub! '<!-- {{EXT_REFERENCE}} -->', ext_reference

      # TODO must be the embedded building instead of the referenced
      building = coder.encode(generate_building(data), :named)
      html.gsub! '<!-- {{BUILDING}} -->', building

      # TODO must be the embedded customer instead of the referenced
      addresslines = coder.encode(generate_addresslines(data), :named)
      html.gsub! '<!-- {{ADDRESSLINES}} -->', addresslines

      # TODO must be the embedded customer instead of the referenced
      contactlines = coder.encode(generate_contactlines(data), :named)
      html.gsub! '<!-- {{CONTACTLINES}} -->', contactlines

      request_number = generate_request_number(data)
      html.gsub! '<!-- {{REQUEST_NUMBER}} -->', request_number

      pricing = generate_pricing(data)
      html.gsub! '<!-- {{INVOICELINES}} -->', pricing[:invoicelines]
      html.gsub! '<!-- {{TOTAL_NET_PRICE}} -->', format_decimal(pricing[:total_net_price])
      html.gsub! '<!-- {{VAT_RATE}} -->', format_vat_rate(pricing[:vat_rate])
      html.gsub! '<!-- {{TOTAL_VAT}} -->', format_decimal(pricing[:total_vat])
      html.gsub! '<!-- {{TOTAL_GROSS_DEPOSIT_INVOICE}} -->', format_decimal(pricing[:total_gross_deposit_invoice])
      html.gsub! '<!-- {{TOTAL_NET_DEPOSIT_INVOICE}} -->', format_decimal(pricing[:total_net_deposit_invoice])

      payment_due_date = generate_payment_due_date(data)
      html.sub! '<!-- {{PAYMENT_DUE_DATE}} -->', payment_due_date

      generate_certificate_notification(data)

      html.sub! '<!-- {{INLINE_CSS}} -->', @inline_css

      footer_path = select_footer(data, language)
      write_to_pdf(path, html, footer_path)
    end

    def select_template(data, language)
      if language == 'FRA'
        ENV['DEPOSIT_INVOICE_TEMPLATE_FR'] || '/templates/voorschotfactuur-fr.html'
      else
        ENV['DEPOSIT_INVOICE_TEMPLATE_NL'] || '/templates/voorschotfactuur-nl.html'
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

    def generate_request_number(data)
      order = data['order']
      if order
        "<b>AD #{order['requestNumber']}</b>"
      else
        hide_element('introduction--reference')
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

      total_net_price = prices.inject(:+) || 0
      vat_rate = data['vatRate']['rate']
      total_vat = total_net_price * vat_rate / 100
      total_gross_deposit_invoice = data['totalAmount']
      total_net_deposit_invoice = data['baseAmount']
      is_taxfree = data['vatRate']['code'] == 'm'

      display_element('invoiceline .taxfree', 'inline') if is_taxfree

      {
        invoicelines: invoicelines.join,
        total_net_price: total_net_price,
        vat_rate: vat_rate,
        total_vat: total_vat,
        total_gross_deposit_invoice: total_gross_deposit_invoice,
        total_net_deposit_invoice: total_net_deposit_invoice
      }
    end

    def generate_payment_due_date(data)
      if data['dueDate']
        format_date(data['dueDate'])
      else
        hide_element('payment-notification--deadline')
        ''
      end
    end

    def generate_certificate_notification(data)
      hide_element('certificate-notification') if not data['certificateRequired'] or data['certificateReceived']
    end
  end
end
