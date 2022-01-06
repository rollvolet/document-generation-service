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

    def generate(path, data)
      coder = HTMLEntities.new

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

      request_number = generate_request_number(data)
      html.gsub! '<!-- {{REQUEST_NUMBER}} -->', request_number

      pricing = generate_pricing(data)
      html.gsub! '<!-- {{INVOICELINES}} -->', coder.encode(pricing[:invoicelines], :named)
      html.gsub! '<!-- {{TOTAL_NET_PRICE}} -->', format_decimal(pricing[:total_net_price])
      html.gsub! '<!-- {{VAT_RATE}} -->', format_vat_rate(pricing[:vat_rate])
      html.gsub! '<!-- {{TOTAL_NET_DEPOSIT_INVOICE}} -->', format_decimal(pricing[:total_net_deposit_invoice])
      html.gsub! '<!-- {{TOTAL_VAT_DEPOSIT_INVOICE}} -->', format_decimal(pricing[:total_vat_deposit_invoice])
      html.gsub! '<!-- {{TOTAL_GROSS_DEPOSIT_INVOICE}} -->', format_decimal(pricing[:total_gross_deposit_invoice])

      unless data['isCreditNote']
        if data['paymentDate']
          hide_element('invoiceline.summary.priceline-to-pay')
          hide_element('payment-notification')
          display_element('invoiceline.summary.priceline-already-paid')
        else
          payment_due_date = generate_payment_due_date(data)
          html.gsub! '<!-- {{PAYMENT_DUE_DATE}} -->', payment_due_date
          bank_reference = generate_bank_reference(data)
          html.gsub! '<!-- {{BANK_REFERENCE}} -->', bank_reference
        end

        generate_certificate_notification(data)
      end

      html.sub! '<!-- {{INLINE_CSS}} -->', @inline_css

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
          ENV['DEPOSIT_INVOICE_HEADER_TEMPLATE_FR'] || '/templates/voorschotfactuur-header-fr.html'
        else
          ENV['DEPOSIT_INVOICE_HEADER_TEMPLATE_NL'] || '/templates/voorschotfactuur-header-nl.html'
        end
      end
    end

    def select_template(data, language)
      if data['isCreditNote']
        if language == 'FRA'
          ENV['DEPOSIT_INVOICE_CREDIT_NOTE_TEMPLATE_FR'] || '/templates/voorschotfactuur-creditnota-fr.html'
        else
          ENV['DEPOSIT_INVOICE_CREDIT_NOTE_TEMPLATE_NL'] || '/templates/voorschotfactuur-creditnota-nl.html'
        end
      else
        if language == 'FRA'
          ENV['DEPOSIT_INVOICE_TEMPLATE_FR'] || '/templates/voorschotfactuur-fr.html'
        else
          ENV['DEPOSIT_INVOICE_TEMPLATE_NL'] || '/templates/voorschotfactuur-nl.html'
        end
      end
    end

    def document_title(data, language)
      number = generate_invoice_number(data)
      document_type = if data['isCreditNote'] then 'C' else 'VF' end
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

    def generate_request_number(data)
      order = data['order']
      if order
        "<b>AD #{format_request_number(order['requestNumber'])}</b>"
      else
        hide_element('introduction--reference')
      end
    end

    def generate_bank_reference(data)
      base = if data['isCreditNote'] then 8000000000 else 5000000000 end
      generate_bank_reference_with_base(base, data['number'])
    end

    def generate_pricing(data)
      invoicelines = []
      prices = []

      if data['order']
        order_uri = get_resource_uri('orders', data['order']['id'])

        query = " PREFIX schema: <http://schema.org/>"
        query += " PREFIX dct: <http://purl.org/dc/terms/>"
        query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
        query += " PREFIX prov: <http://www.w3.org/ns/prov#>"
        query += " SELECT ?description ?amount"
        query += " WHERE {"
        query += "   GRAPH <http://mu.semte.ch/graphs/rollvolet> {"
        query += "     ?invoiceline a crm:Invoiceline ;"
        query += "       prov:wasDerivedFrom <#{order_uri}> ;"
        query += "       dct:description ?description ;"
        query += "       schema:amount ?amount ."
        query += "   }"
        query += " }"

        solutions = query(query)

        solutions.each do |invoiceline|
          prices << invoiceline[:amount]
          line = "<div class='invoiceline'>"
          line += "  <div class='col col-1-2'>#{invoiceline[:description]}</div>"
          line += "</div>"
          invoicelines << line
        end
      end

      total_net_price = prices.inject(:+) || 0
      vat_rate = data['vatRate']['rate']
      total_gross_deposit_invoice = data['totalAmount']
      total_net_deposit_invoice = data['baseAmount']
      total_vat_deposit_invoice = total_net_deposit_invoice * vat_rate / 100
      is_taxfree = data['vatRate']['code'] == 'm'

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
