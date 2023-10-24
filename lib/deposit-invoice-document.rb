# coding: utf-8
require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class DepositInvoiceDocument < Document
    def initialize(*args, **keywords)
      super(*args, **keywords)
      @file_type = 'http://data.rollvolet.be/concepts/5c93373f-30f3-454c-8835-15140ff6d1d4'
    end

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
      _case = fetch_case(deposit_invoice[:case_uri])
      request = fetch_request(_case[:request][:id]) if _case[:request]
      intervention = fetch_intervention(_case[:intervention][:id]) if _case[:intervention]
      customer = fetch_customer(_case[:customer][:uri]) if _case[:customer]
      contact = fetch_contact(_case[:contact][:uri]) if _case[:contact]
      building = fetch_building(_case[:building][:uri]) if _case[:building]

      init_template(deposit_invoice)

      invoice_number = generate_invoice_number(deposit_invoice)
      fill_placeholder('NUMBER', invoice_number)

      fill_placeholder('DATE', format_date(deposit_invoice[:date]))

      fill_placeholder('CUSTOMER_NUMBER', customer[:number])

      own_reference = generate_own_reference(request: request, intervention: intervention)
      fill_placeholder('OWN_REFERENCE', own_reference, encode: true)

      ext_reference = generate_ext_reference(_case)
      fill_placeholder('EXT_REFERENCE', ext_reference, encode: true)

      building_lines = generate_address(building, 'building')
      fill_placeholder('BUILDING', building_lines, encode: true)

      addresslines = generate_address(customer)
      fill_placeholder('ADDRESSLINES', addresslines, encode: true)

      contactlines = generate_contactlines(customer: customer, contact: contact)
      fill_placeholder('CONTACTLINES', contactlines, encode: true)

      fill_placeholder('REQUEST_NUMBER', format_request_number(request[:number]))

      fill_placeholder('OUTRO', deposit_invoice[:outro] || '', encode: true)

      pricing = generate_pricing(deposit_invoice, _case[:order][:uri])
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

      generate_and_upload_file deposit_invoice[:uri]
      @path
    end

    def generate_bank_reference(invoice)
      base = if invoice[:is_credit_note] then 8000000000 else 5000000000 end
      generate_bank_reference_with_base(base, invoice[:number].to_i)
    end

    def generate_pricing(deposit_invoice, order_uri)
      invoicelines = []
      prices = []

      if order_uri
        solutions = fetch_invoicelines(order_uri: order_uri)
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
