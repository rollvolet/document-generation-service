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

      pricing = generate_pricing(data)
      html.gsub! '<!-- {{INVOICELINES}} -->', pricing[:invoicelines]
      html.gsub! '<!-- {{TOTAL_NET_PRICE}} -->', format_decimal(pricing[:total_net_price])
      html.gsub! '<!-- {{VAT_RATE}} -->', format_vat_rate(pricing[:vat_rate])
      html.gsub! '<!-- {{TOTAL_VAT}} -->', format_decimal(pricing[:total_vat])
      html.gsub! '<!-- {{TOTAL_DEPOSITS}} -->', format_decimal(pricing[:total_deposits])
      html.gsub! '<!-- {{TOTAL_DEPOSIT_INVOICES}} -->', format_decimal(pricing[:total_deposit_invoices])
      html.gsub! '<!-- {{TOTAL_GROSS_PRICE}} -->', format_decimal(pricing[:total_gross_price])

      payment_due_date = generate_payment_due_date(data)
      html.gsub! '<!-- {{PAYMENT_DUE_DATE}} -->', payment_due_date

      generate_certificate_notification(data)

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

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
          nb = supplement['nbOfPieces'] || 1.0
          nb_display = if nb % 1 == 0 then nb.floor else format_decimal(nb) end

          unit = supplement['unit'] || ''
          unit_separator = if unit == 'm' or unit == 'm2' then '' else ' ' end
          unit = 'm<sup>2</sup>' if unit == 'm2'

          line_price = nb * supplement['amount']

          prices << line_price
          line = "<div class='invoiceline'>"
          line += "  <div class='col col-1'>#{nb_display}#{unit_separator}#{unit} #{supplement['description']}</div>"
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
