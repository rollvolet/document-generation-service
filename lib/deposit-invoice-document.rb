# coding: utf-8
require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class DepositInvoiceDocument < Document
    def init_template deposit_invoice
      if deposit_invoice[:is_credit_note]
        if @language == 'FRA'
          template_path = ENV['DEPOSIT_INVOICE_CREDIT_NOTE_TEMPLATE_FR'] || '/templates/voorschotfactuur-creditnota-fr.html'
          header_path = ENV['DEPOSIT_INVOICE_CREDIT_NOTE_HEADER_TEMPLATE_FR'] || '/templates/creditnota-header-fr.html'
        else
          template_path = ENV['DEPOSIT_INVOICE_CREDIT_NOTE_TEMPLATE_NL'] || '/templates/voorschotfactuur-creditnota-nl.html'
          header_path = ENV['DEPOSIT_INVOICE_CREDIT_NOTE_HEADER_TEMPLATE_NL'] || '/templates/creditnota-header-nl.html'
        end
      else
        if @language == 'FRA'
          template_path = ENV['DEPOSIT_INVOICE_TEMPLATE_FR'] || '/templates/voorschotfactuur-fr.html'
          header_path = ENV['DEPOSIT_INVOICE_HEADER_TEMPLATE_FR'] || '/templates/voorschotfactuur-header-fr.html'
        else
          template_path = ENV['DEPOSIT_INVOICE_TEMPLATE_NL'] || '/templates/voorschotfactuur-nl.html'
          header_path = ENV['DEPOSIT_INVOICE_HEADER_TEMPLATE_NL'] || '/templates/voorschotfactuur-header-nl.html'
        end
      end

      @html = File.open(template_path, 'rb') { |file| file.read }
      @header = if header_path then File.open(header_path, 'rb') { |f| f.read } else '' end
      footer_path = select_footer(nil, @language)
      @footer = if footer_path then File.open(footer_path, 'rb') { |f| f.read } else '' end

      invoice_number = generate_invoice_number(deposit_invoice)
      fill_placeholder('NUMBER', invoice_number, template: @header)
      document_type = if deposit_invoice[:is_credit_note] then 'C' else 'VF' end
      @document_title = "#{document_type}#{invoice_number}"
    end

    def generate(data)
      deposit_invoice = fetch_invoice(@resource_id)
      customer = find_included_record_by_type(data, 'customer-snapshots')
      contact = find_included_record_by_type(data, 'contact-snapshots')
      building = find_included_record_by_type(data, 'building-snapshots')
      request = find_included_record_by_type(data, 'requests')
      offer = find_included_record_by_type(data, 'offers')
      order = find_included_record_by_type(data, 'orders')

      init_template(deposit_invoice)

      invoice_number = generate_invoice_number(deposit_invoice)
      fill_placeholder('NUMBER', invoice_number)

      invoice_date = generate_invoice_date(deposit_invoice)
      fill_placeholder('DATE', invoice_date)

      customer_number = customer['attributes']['number'].to_s
      fill_placeholder('CUSTOMER_NUMBER', customer_number)

      own_reference = generate_own_reference(request, offer)
      fill_placeholder('OWN_REFERENCE', own_reference, encode: true)

      ext_reference = generate_ext_reference(deposit_invoice)
      fill_placeholder('EXT_REFERENCE', ext_reference, encode: true)

      building_address = find_related_record(building, data, 'address')
      building_lines = generate_embedded_address(building, building_address, 'building')
      fill_placeholder('BUILDING', building_lines, encode: true)

      customer_address = find_related_record(customer, data, 'address')
      addresslines = generate_embedded_address(customer, customer_address)
      fill_placeholder('ADDRESSLINES', addresslines, encode: true)

      contactlines = generate_embedded_contactlines(customer, contact)
      fill_placeholder('CONTACTLINES', contactlines, encode: true)

      request_number = generate_request_number(order)
      fill_placeholder('REQUEST_NUMBER', request_number)

      fill_placeholder('OUTRO', deposit_invoice[:outro] || '', encode: true)

      pricing = generate_pricing(deposit_invoice, order)
      fill_placeholder('INVOICELINES', pricing[:invoicelines], encode: true)
      fill_placeholder('VAT_RATE', format_vat_rate(pricing[:vat_rate]))
      fill_placeholder('TOTAL_NET_PRICE', format_decimal(pricing[:total_net_price]))
      fill_placeholder('TOTAL_NET_DEPOSIT_INVOICE', format_decimal(pricing[:total_net_deposit_invoice]))
      fill_placeholder('TOTAL_VAT_DEPOSIT_INVOICE', format_decimal(pricing[:total_vat_deposit_invoice]))
      fill_placeholder('TOTAL_GROSS_DEPOSIT_INVOICE', format_decimal(pricing[:total_gross_deposit_invoice]))

      unless deposit_invoice[:is_credit_note]
        if deposit_invoice[:payment_date]
          hide_element('invoiceline.summary.priceline-to-pay')
          hide_element('payment-notification')
          display_element('invoiceline.summary.priceline-already-paid')
        else
          payment_due_date = generate_payment_due_date(deposit_invoice)
          fill_placeholder('PAYMENT_DUE_DATE', payment_due_date)
          bank_reference = generate_bank_reference(deposit_invoice)
          fill_placeholder('BANK_REFERENCE', bank_reference)
        end

        hide_element('certificate-notification') unless deposit_invoice[:vat_code] == '6'
        hide_element('btw-verlegd') unless deposit_invoice[:vat_code] == 'm'
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

    def generate_request_number(request)
      if request
        "<b>AD #{format_request_number(request['id'])}</b>"
      else
        hide_element('introduction--reference')
      end
    end

    def generate_bank_reference(invoice)
      base = if invoice[:is_credit_note] then 8000000000 else 5000000000 end
      generate_bank_reference_with_base(base, invoice[:number].to_i)
    end

    def generate_pricing(deposit_invoice, order)
      invoicelines = []
      prices = []

      if order
        solutions = fetch_invoicelines(order_id: order['id'])
        solutions.each do |invoiceline|
          prices << invoiceline[:amount]
          line = "<div class='invoiceline'>"
          line += "  <div class='col col-1-2'>#{invoiceline[:description]}</div>"
          line += "</div>"
          invoicelines << line
        end
      end

      total_net_price = prices.inject(:+) || 0
      vat_rate = deposit_invoice[:vat_rate]
      total_net_deposit_invoice = deposit_invoice[:amount]
      total_vat_deposit_invoice = total_net_deposit_invoice * vat_rate / 100
      total_gross_deposit_invoice = total_net_deposit_invoice + total_vat_deposit_invoice

      is_taxfree = deposit_invoice[:vat_code] == 'm'
      if is_taxfree
        display_element('invoiceline.summary .col.taxfree', 'inline-block')
        hide_element('invoiceline.summary .col.not-taxfree')
      end

      {
        invoicelines: invoicelines.join,
        total_net_price: total_net_price,
        vat_rate: vat_rate,
        total_net_deposit_invoice: total_net_deposit_invoice,
        total_vat_deposit_invoice: total_vat_deposit_invoice,
        total_gross_deposit_invoice: total_gross_deposit_invoice
      }
    end
  end
end
