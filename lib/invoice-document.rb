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

    def generate(path, data)
      coder = HTMLEntities.new

      is_credit_note =  data['isCreditNote']

      language = select_language(data)
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

      pricing = generate_pricing(data, language, coder)
      html.gsub! '<!-- {{INVOICELINES}} -->', coder.encode(pricing[:invoicelines], :named)
      html.gsub! '<!-- {{VAT_RATE}} -->', format_vat_rate(pricing[:vat_rate])
      html.gsub! '<!-- {{TOTAL_NET_ORDER_PRICE}} -->', format_decimal(pricing[:total_net_order_price]) unless is_credit_note
      html.gsub! '<!-- {{TOTAL_VAT_ORDER_PRICE}} -->', format_decimal(pricing[:total_vat_order_price]) unless is_credit_note
      html.gsub! '<!-- {{TOTAL_GROSS_ORDER_PRICE}} -->', format_decimal(pricing[:total_gross_order_price]) unless is_credit_note
      html.gsub! '<!-- {{TOTAL_NET_DEPOSIT_INVOICES}} -->', format_decimal(pricing[:total_net_deposit_invoices]) unless is_credit_note
      html.gsub! '<!-- {{TOTAL_VAT_DEPOSIT_INVOICES}} -->', format_decimal(pricing[:total_vat_deposit_invoices]) unless is_credit_note
      html.gsub! '<!-- {{TOTAL_GROSS_DEPOSIT_INVOICES}} -->', format_decimal(pricing[:total_gross_deposit_invoices]) unless is_credit_note
      html.gsub! '<!-- {{DEPOSIT_INVOICE_NUMBERS}} -->', pricing[:deposit_invoice_numbers] unless is_credit_note
      html.gsub! '<!-- {{TOTAL_NET}} -->', format_decimal(pricing[:total_net])
      html.gsub! '<!-- {{TOTAL_VAT}} -->', format_decimal(pricing[:total_vat])
      html.gsub! '<!-- {{TOTAL_GROSS}} -->', format_decimal(pricing[:total_gross])
      html.gsub! '<!-- {{TOTAL_DEPOSITS}} -->', format_decimal(pricing[:total_deposits]) unless is_credit_note
      html.gsub! '<!-- {{TOTAL_TO_PAY}} -->', format_decimal(pricing[:total_to_pay])

      unless is_credit_note
        if data['paymentDate']
          hide_element('priceline.priceline-to-pay')
          hide_element('payment-notification')
          display_element('priceline.priceline-already-paid')
        else
          payment_due_date = generate_payment_due_date(data)
          html.gsub! '<!-- {{PAYMENT_DUE_DATE}} -->', payment_due_date
          bank_reference = generate_bank_reference(data)
          html.gsub! '<!-- {{BANK_REFERENCE}} -->', bank_reference
        end

        generate_certificate_notification(data)
      end

      if data['order']
        hide_element('priceline-total-order .intervention-key')
      else
        hide_element('priceline-total-order .order-key')
      end

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      header_path = select_header(data, language)
      header_html = if header_path then File.open(header_path, 'rb') { |file| file.read } else '' end
      header_html.gsub! '<!-- {{NUMBER}} -->', invoice_number

      footer_path = select_footer(data, language)
      footer_html = if footer_path then File.open(footer_path, 'rb') { |file| file.read } else '' end

      document_title = document_title(data, language)

      write_to_pdf(path, html, header: { content: header_html }, footer: { content: footer_html }, title: document_title)
    end

    def select_header(data, language)
      if data['isCreditNote']
        if language == 'FRA'
          ENV['CREDIT_NOTE_HEADER_TEMPLATE_FR'] || '/templates/creditnota-header-fr.html'
        else
          ENV['CREDIT_NOTE_HEADER_TEMPLATE_NL'] || '/templates/creditnota-header-nl.html'
        end
      else
        if language == 'FRA'
          ENV['INVOICE_HEADER_TEMPLATE_FR'] || '/templates/factuur-header-fr.html'
        else
          ENV['INVOICE_HEADER_TEMPLATE_NL'] || '/templates/factuur-header-nl.html'
        end
      end
    end

    def select_template(data, language)
      if data['isCreditNote']
        if language == 'FRA'
          ENV['CREDIT_NOTE_TEMPLATE_FR'] || '/templates/creditnota-fr.html'
        else
          ENV['CREDIT_NOTE_TEMPLATE_NL'] || '/templates/creditnota-nl.html'
        end
      else
        if language == 'FRA'
          ENV['INVOICE_TEMPLATE_FR'] || '/templates/factuur-fr.html'
        else
          ENV['INVOICE_TEMPLATE_NL'] || '/templates/factuur-nl.html'
        end
      end
    end

    def document_title(data, language)
      number = generate_invoice_number(data)
      document_type = if data['isCreditNote'] then 'C' else 'F' end
      "#{document_type}#{number}"
    end

    def generate_own_reference(data)
      order = data['order']
      if order
        offer = order['offer']
        own_reference = "<b>AD #{format_request_number(order['requestNumber'])}</b>"
        own_reference += " <b>#{data['visit']['visitor']}</b>" if data['visit']
        own_reference += "<br><span class='note'>#{offer['number']} #{offer['documentVersion']}</span>"
        own_reference
      else
        hide_element('references--own_reference')
      end
    end

    def generate_bank_reference(data)
      base = if data['isCreditNote'] then 8000000000 else 0 end
      generate_bank_reference_with_base(base, data['number'])
    end

    def generate_pricing(data, language, coder)
      invoicelines = []
      prices = []

      # we assume all invoicelines have the same VAT rate as the invoice
      data['invoicelines'].each do |invoiceline|
        prices << invoiceline['amount']
        line = "<div class='invoiceline'>"
        line += "  <div class='col col-1'>#{invoiceline['description']}</div>"
        line += "  <div class='col col-2'>&euro; #{format_decimal(invoiceline['amount'])}</div>"
        line += "</div>"
        invoicelines << line
      end

      if data['supplements']
        data['supplements'].each do |supplement|
          nb = supplement['nbOfPieces'] || 1.0
          nb_display = if nb % 1 == 0 then nb.floor else format_decimal(nb) end

          unit = ''
          if (supplement['unit'])
            unit_code = supplement['unit']['code']
            unit_separator = if unit == 'M' or unit == 'M2' then '' else ' ' end
            unit = if language == 'FRA' then supplement['unit']['nameFra'] else supplement['unit']['nameNed'] end
            unit = coder.encode(unit, :named)
            unit = 'm<sup>2</sup>' if unit_code == 'M2'
          end

          line_price = supplement['amount'] || 0

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
        deposit_invoices = data['depositInvoices'].map do |d|
          amount = d['amount'] || 0
          if d['isCreditNote'] then amount * -1.0 else amount end
        end
        deposit_invoice_numbers = data['depositInvoices'].map { |d| generate_invoice_number(d) }.join(', ')
      end

      # we assume invoice and deposit-invoices have the same VAT rate
      vat_rate = data['vatRate']['rate']

      total_net_order_price = prices.inject(:+) || 0  # sum of invoicelines and supplements
      total_vat_order_price = total_net_order_price * vat_rate / 100
      total_gross_order_price = total_net_order_price + total_vat_order_price

      total_net_deposit_invoices = deposit_invoices.inject(:+) || 0
      total_vat_deposit_invoices = total_net_deposit_invoices * vat_rate / 100
      total_gross_deposit_invoices = total_net_deposit_invoices + total_vat_deposit_invoices

      total_net = total_net_order_price - total_net_deposit_invoices
      total_vat = total_net * vat_rate / 100
      total_gross = total_net + total_vat

      total_deposits = deposits.inject(:+) || 0
      total_to_pay = total_gross - total_deposits

      hide_element('priceline-deposit') if total_deposits == 0
      if total_net_deposit_invoices == 0
        hide_element('priceline-total-order')
        hide_element('priceline-deposit-invoice')
      end

      is_taxfree = data['vatRate']['code'] == 'm'
      if is_taxfree
        display_element('invoiceline.summary .col.taxfree', 'inline-block')
        display_element('priceline .col.taxfree', 'inline-block')
        hide_element('invoiceline.summary .col.not-taxfree')
        hide_element('priceline .col.not-taxfree')
      end

      is_six_pct_vat = data['vatRate']['code'] == '6'
      hide_element('vat-6-pct') unless is_six_pct_vat

      {
        invoicelines: invoicelines.join,
        vat_rate: vat_rate,
        total_net_order_price: total_net_order_price,
        total_vat_order_price: total_vat_order_price,
        total_gross_order_price: total_gross_order_price,
        total_net_deposit_invoices: total_net_deposit_invoices,
        total_vat_deposit_invoices: total_vat_deposit_invoices,
        total_gross_deposit_invoices: total_gross_deposit_invoices,
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
