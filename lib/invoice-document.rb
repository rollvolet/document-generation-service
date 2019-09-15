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

      outro = coder.encode(data['documentOutro'] || '', :named)
      html.gsub! '<!-- {{OUTRO}} -->', outro

      pricing = generate_pricing(data)
      html.gsub! '<!-- {{INVOICELINES}} -->', coder.encode(pricing[:invoicelines], :named)
      html.gsub! '<!-- {{VAT_RATE}} -->', format_vat_rate(pricing[:vat_rate])
      html.gsub! '<!-- {{TOTAL_NET_ORDER_PRICE}} -->', format_decimal(pricing[:total_net_order_price])
      html.gsub! '<!-- {{TOTAL_NET_DEPOSIT_INVOICES}} -->', format_decimal(pricing[:total_net_deposit_invoices])
      html.gsub! '<!-- {{DEPOSIT_INVOICE_NUMBERS}} -->', pricing[:deposit_invoice_numbers]
      html.gsub! '<!-- {{TOTAL_NET}} -->', format_decimal(pricing[:total_net])
      html.gsub! '<!-- {{TOTAL_VAT}} -->', format_decimal(pricing[:total_vat])
      html.gsub! '<!-- {{TOTAL_GROSS}} -->', format_decimal(pricing[:total_gross])
      html.gsub! '<!-- {{TOTAL_DEPOSITS}} -->', format_decimal(pricing[:total_deposits])
      html.gsub! '<!-- {{TOTAL_TO_PAY}} -->', format_decimal(pricing[:total_to_pay])

      payment_due_date = generate_payment_due_date(data)
      html.gsub! '<!-- {{PAYMENT_DUE_DATE}} -->', payment_due_date

      generate_certificate_notification(data)

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      header_path = select_header(data, language)
      header_html = if header_path then File.open(header_path, 'rb') { |file| file.read } else '' end
      header_html.gsub! '<!-- {{NUMBER}} -->', invoice_number

      footer_path = select_footer(data, language)
      footer_html = if footer_path then File.open(footer_path, 'rb') { |file| file.read } else '' end

      write_to_pdf(path, html, header_html, footer_html)
    end

    def select_header(data, language)
      if language == 'FRA'
        ENV['INVOICE_HEADER_TEMPLATE_FR'] || '/templates/factuur-header-fr.html'
      else
        ENV['INVOICE_HEADER_TEMPLATE_NL'] || '/templates/factuur-header-nl.html'
      end
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

          line_price = supplement['amount']

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
      deposit_invoice_numbers = []
      if data['depositInvoices']
        deposit_invoices = data['depositInvoices'].map { |d| d['amount'] || 0}
        deposit_invoice_numbers = data['depositInvoices'].map { |d| generate_invoice_number(d) }.join(', ')
      end

      # TODO we assume invoice and deposit-invoices have the same VAT rate
      vat_rate = data['vatRate']['rate']
      total_net_order_price = prices.inject(:+) || 0  # sum of ordered offerlines and supplements
      total_net_deposit_invoices = deposit_invoices.inject(:+) || 0
      total_net = total_net_order_price - total_net_deposit_invoices
      total_vat = total_net * vat_rate / 100
      total_gross = total_net + total_vat
      total_deposits = deposits.inject(:+) || 0
      total_to_pay = total_gross - total_deposits
      is_taxfree = data['vatRate']['code'] == 'm'

      hide_element('priceline-deposit') if total_deposits == 0
      hide_element('priceline-deposit-invoice') if total_net_deposit_invoices == 0

      if is_taxfree
        display_element('invoiceline .col.taxfree', 'inline-block')
        hide_element('invoiceline .col.not-taxfree')
      end

      {
        invoicelines: invoicelines.join,
        vat_rate: vat_rate,
        total_net_order_price: total_net_order_price,
        total_net_deposit_invoices: total_net_deposit_invoices,
        deposit_invoice_numbers: deposit_invoice_numbers,
        total_net: total_net,
        total_vat: total_vat,
        total_gross: total_gross,
        total_deposits: total_deposits,
        total_to_pay: total_to_pay
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
