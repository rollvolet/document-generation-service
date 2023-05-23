# coding: utf-8
require 'wicked_pdf'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class InvoiceDocument < Document
    def init_template invoice
      if invoice[:is_credit_note]
        if @language == 'FRA'
          template_path = ENV['CREDIT_NOTE_TEMPLATE_FR'] || '/templates/creditnota-fr.html'
          header_path = ENV['CREDIT_NOTE_HEADER_TEMPLATE_FR'] || '/templates/creditnota-header-fr.html'
        else
          template_path = ENV['CREDIT_NOTE_TEMPLATE_NL'] || '/templates/creditnota-nl.html'
          header_path = ENV['CREDIT_NOTE_HEADER_TEMPLATE_NL'] || '/templates/creditnota-header-nl.html'
        end
      else
        if @language == 'FRA'
          template_path = ENV['INVOICE_TEMPLATE_FR'] || '/templates/factuur-fr.html'
          header_path = ENV['INVOICE_HEADER_TEMPLATE_FR'] || '/templates/factuur-header-fr.html'
        else
          template_path = ENV['INVOICE_TEMPLATE_NL'] || '/templates/factuur-nl.html'
          header_path = ENV['INVOICE_HEADER_TEMPLATE_NL'] || '/templates/factuur-header-nl.html'
        end
      end

      @html = File.open(template_path, 'rb') { |file| file.read }
      @header = if header_path then File.open(header_path, 'rb') { |f| f.read } else '' end
      footer_path = select_footer(nil, @language)
      @footer = if footer_path then File.open(footer_path, 'rb') { |f| f.read } else '' end

      invoice_number = generate_invoice_number(invoice)
      fill_placeholder('NUMBER', invoice_number, template: @header)
      document_type = if invoice[:is_credit_note] then 'C' else 'F' end
      @document_title = "#{document_type}#{invoice_number}"
    end

    def generate(data)
      invoice = fetch_invoice(@resource_id)
      customer = find_included_record_by_type(data, 'customer-snapshots')
      contact = find_included_record_by_type(data, 'contact-snapshots')
      building = find_included_record_by_type(data, 'building-snapshots')
      request = find_included_record_by_type(data, 'requests')
      offer = find_included_record_by_type(data, 'offers')
      order = find_included_record_by_type(data, 'orders')

      init_template(invoice)

      invoice_number = generate_invoice_number(invoice)
      fill_placeholder('NUMBER', invoice_number)

      invoice_date = generate_invoice_date(invoice)
      fill_placeholder('DATE', invoice_date)

      customer_number = customer['attributes']['number'].to_s
      fill_placeholder('CUSTOMER_NUMBER', customer_number)

      own_reference = generate_own_reference(request, offer)
      fill_placeholder('OWN_REFERENCE', own_reference, encode: true)

      ext_reference = generate_ext_reference(invoice)
      fill_placeholder('EXT_REFERENCE', ext_reference, encode: true)

      building_address = find_related_record(building, data, 'address')
      building_lines = generate_embedded_address(building, building_address, 'building')
      fill_placeholder('BUILDING', building_lines, encode: true)

      customer_address = find_related_record(customer, data, 'address')
      addresslines = generate_embedded_address(customer, customer_address)
      fill_placeholder('ADDRESSLINES', addresslines, encode: true)

      contactlines = generate_embedded_contactlines(customer, contact)
      fill_placeholder('CONTACTLINES', contactlines, encode: true)

      fill_placeholder('OUTRO', invoice[:outro] || '', encode: true)

      pricing = generate_pricing(invoice)
      fill_placeholder('INVOICELINES', pricing[:invoicelines], encode: true)
      fill_placeholder('VAT_RATE', format_vat_rate(pricing[:vat_rate]))
      fill_placeholder('TOTAL_NET', format_decimal(pricing[:total_net]))
      fill_placeholder('TOTAL_VAT', format_decimal(pricing[:total_vat]))
      fill_placeholder('TOTAL_GROSS', format_decimal(pricing[:total_gross]))
      fill_placeholder('TOTAL_TO_PAY', format_decimal(pricing[:total_to_pay]))

      unless invoice[:is_credit_note]
        fill_placeholder('TOTAL_NET_ORDER_PRICE', format_decimal(pricing[:total_net_order_price]))
        fill_placeholder('TOTAL_GROSS_ORDER_PRICE', format_decimal(pricing[:total_gross_order_price]))
        fill_placeholder('TOTAL_NET_DEPOSIT_INVOICES', format_decimal(pricing[:total_net_deposit_invoices]))
        fill_placeholder('TOTAL_VAT_DEPOSIT_INVOICES', format_decimal(pricing[:total_vat_deposit_invoices]))
        fill_placeholder('TOTAL_GROSS_DEPOSIT_INVOICES', format_decimal(pricing[:total_gross_deposit_invoices]))
        fill_placeholder('DEPOSIT_INVOICE_NUMBERS', pricing[:deposit_invoice_numbers])
        fill_placeholder('TOTAL_VAT_ORDER_PRICE', format_decimal(pricing[:total_vat_order_price]))
        fill_placeholder('TOTAL_DEPOSITS', format_decimal(pricing[:total_deposits]))

        if invoice[:payment_date]
          hide_element('priceline.priceline-to-pay')
          hide_element('payment-notification')
          display_element('priceline.priceline-already-paid')
        else
          payment_due_date = generate_payment_due_date(invoice)
          fill_placeholder('PAYMENT_DUE_DATE', payment_due_date)
          bank_reference = generate_bank_reference(invoice)
          fill_placeholder('BANK_REFERENCE', bank_reference)
        end

        hide_element('certificate-notification') unless invoice[:vat_code] == '6'
        hide_element('btw-verlegd') unless invoice[:vat_code] == 'm'
      end

      if order
        hide_element('priceline-total-order .intervention-key')
      else
        hide_element('priceline-total-order .order-key')
      end

      write_file
    end

    def generate_own_reference(request, offer)
      if request and offer
        own_reference = "<b>AD #{format_request_number(request['id'])}</b>"
        if request['attributes']['visitor']
          employee = fetch_employee_by_name(request['attributes']['visitor'])
          own_reference += " <b>#{employee[:initials]}</b>" if employee
        end
        own_reference += "<br><span class='note'>#{offer['attributes']['number']} #{offer['attributes']['document-version']}</span>"
        own_reference
      else
        hide_element('references--own_reference')
      end
    end

    def generate_embedded_address(record, address, hide_class = nil)
      if record
        addresslines = "#{record['attributes']['name']}<br>"
        if address
          if address['attributes']['street']
            streetlines = address['attributes']['street'].gsub(/\n/, '<br>')
            addresslines += "#{streetlines}<br>"
          end
          addresslines += "#{address['attributes']['postal-code']} #{address['attributes']['city']}" if address['attributes']['postal-code'] or address['attributes']['city']
        end
        addresslines
      elsif hide_class
        hide_element(hide_class)
      end
    end

    def generate_embedded_contactlines(customer, contact)
      vat_number = customer['attributes']['vat-number']
      contactlines = if vat_number then "<div class='contactline contactline--vat-number'>#{format_vat_number(vat_number)}</div>" else '' end

      if contact
        name = "Contact: #{contact['attributes']['name']}"
        contactlines += "<div class='contactline contactline--name'>#{name}</div>"
      end

      contactlines += "<div class='contactline contactline--telephones'>"
      if contact
        telephones = fetch_telephones(contact['id'], 'contacts')
      else
        telephones = fetch_telephones(customer['attributes']['number'])
      end
      top_telephones = telephones.first(2)

      top_telephones.each do |tel|
        formatted_tel = format_telephone(tel[:prefix], tel[:value])
        contactlines += "<span class='contactline contactline--telephone'>#{formatted_tel}</span>"
      end
      contactlines += "</div>"

      contactlines
    end

    def generate_bank_reference(invoice)
      base = if invoice[:is_credit_note] then 8000000000 else 0 end
      generate_bank_reference_with_base(base, invoice[:number].to_i)
    end

    def generate_payment_due_date(invoice)
      if invoice[:due_date]
        format_date(invoice[:due_date])
      else
        hide_element('payment-notification--deadline')
        ''
      end
    end

    def generate_pricing(invoice)
      solutions = fetch_invoicelines(invoice_uri: invoice[:uri])
      invoicelines = []
      prices = []

      # we assume all invoicelines have the same VAT rate as the invoice
      solutions.each do |invoiceline|
        prices << invoiceline[:amount]
        line = "<div class='invoiceline'>"
        line += "  <div class='col col-1'>#{invoiceline[:description]}</div>"
        line += "  <div class='col col-2'>&euro; #{format_decimal(invoiceline[:amount])}</div>"
        line += "</div>"
        invoicelines << line
      end

      deposit_invoices = fetch_deposit_invoices_for_invoice(invoice[:id])
      deposit_invoice_amounts = deposit_invoices.map do |d|
        amount = d[:amount] || 0
        is_credit_note = d[:is_credit_note] == 'https://purl.org/p2p-o/invoice#E-CreditNote'
        if is_credit_note then amount * -1.0 else amount end
      end
      deposit_invoice_numbers = deposit_invoices.map { |d| generate_invoice_number(d) }

      # we assume invoice and deposit-invoices have the same VAT rate
      vat_rate = invoice[:vat_rate]

      total_net_order_price = prices.inject(:+) || 0  # sum of invoicelines
      total_vat_order_price = total_net_order_price * vat_rate / 100
      total_gross_order_price = total_net_order_price + total_vat_order_price

      total_net_deposit_invoices = deposit_invoice_amounts.inject(:+) || 0
      total_vat_deposit_invoices = total_net_deposit_invoices * vat_rate / 100
      total_gross_deposit_invoices = total_net_deposit_invoices + total_vat_deposit_invoices

      total_net = total_net_order_price - total_net_deposit_invoices
      total_vat = total_net * vat_rate / 100
      total_gross = total_net + total_vat

      total_deposits = invoice[:paid_deposits] || 0
      total_to_pay = total_gross - total_deposits

      hide_element('priceline-deposit') if total_deposits == 0
      if total_net_deposit_invoices == 0
        hide_element('priceline-total-order')
        hide_element('priceline-deposit-invoice')
      end

      is_taxfree = invoice[:vat_code] == 'm'
      if is_taxfree
        display_element('invoiceline.summary .col.taxfree', 'inline-block')
        display_element('priceline .col.taxfree', 'inline-block')
        hide_element('invoiceline.summary .col.not-taxfree')
        hide_element('priceline .col.not-taxfree')
      end

      {
        invoicelines: invoicelines.join,
        vat_rate: vat_rate,
        total_net_order_price: total_net_order_price,
        total_vat_order_price: total_vat_order_price,
        total_gross_order_price: total_gross_order_price,
        total_net_deposit_invoices: total_net_deposit_invoices,
        total_vat_deposit_invoices: total_vat_deposit_invoices,
        total_gross_deposit_invoices: total_gross_deposit_invoices,
        deposit_invoice_numbers: deposit_invoice_numbers.join(', '),
        total_net: total_net,
        total_vat: total_vat,
        total_gross: total_gross,
        total_deposits: total_deposits,
        total_to_pay: total_to_pay
      }
    end
  end
end
