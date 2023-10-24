require 'wicked_pdf'
require 'combine_pdf'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class DeliveryNote < Document
    def initialize(*args, **keywords)
      super(*args, **keywords)
      @file_type = 'http://data.rollvolet.be/concepts/dcf1aa80-6b1b-4423-8ce1-4df7ffe85684'
    end

    def init_template request
      request_ref = generate_request_reference request

      if @language == 'FRA'
        template_path = ENV['DELIVERY_NOTE_TEMPLATE_FR'] || '/templates/leveringsbon-fr.html'
        header_path = ENV['DELIVERY_NOTE_HEADER_TEMPLATE_FR'] || '/templates/leveringsbon-header-fr.html'
        @document_title = "Bon de livraison #{request_ref}"
      else
        template_path = ENV['DELIVERY_NOTE_TEMPLATE_NL'] || '/templates/leveringsbon-nl.html'
        header_path = ENV['DELIVERY_NOTE_HEADER_TEMPLATE_NL'] || '/templates/leveringsbon-header-nl.html'
        @document_title = "Leveringsbon #{request_ref}"
      end

      @html = File.read(template_path)
      @header = if header_path then File.read(header_path) else '' end
      footer_path = select_footer(nil, @language)
      @footer = if footer_path then File.read(footer_path) else '' end
    end

    def generate
      order = fetch_order(@resource_id)
      _case = fetch_case(order[:case_uri])
      request = fetch_request(_case[:request][:id]) if _case[:request]
      offer = fetch_offer(_case[:offer][:id]) if _case[:offer]
      customer = fetch_customer(_case[:customer][:uri]) if _case[:customer]
      contact = fetch_contact(_case[:contact][:uri]) if _case[:contact]
      building = fetch_building(_case[:building][:uri]) if _case[:building]

      init_template(request)

      # Store initial state, such that we can reset to this state for each scope
      initial_html = @html.clone
      Mu::log.info "Initial HTML template is #{initial_html}"
      initial_inline_css = @inline_css

      tmp_paths = ['supplier', 'customer'].map do |scope|
        tmp_path = "/tmp/#{@resource_id}-delivery-note-#{scope}.pdf"
        # Reset state
        @inline_css = initial_inline_css
        @html = initial_html.clone

        Mu::log.info "HTML for #{scope} is now #{@html}"

        # Generate document for scope
        # This will modify @html and @inline_css
        own_reference = generate_offer_reference(offer, request)
        fill_placeholder('OWN_REFERENCE', own_reference, encode: true)

        ext_reference = generate_ext_reference(_case)
        fill_placeholder('EXT_REFERENCE', ext_reference, encode: true)

        building_lines = generate_address(building, 'building')
        fill_placeholder('BUILDING', building_lines, encode: true)

        contactlines = generate_contactlines(customer: customer, contact: contact)
        fill_placeholder('CONTACTLINES', contactlines, encode: true)

        addresslines = generate_address(customer)
        fill_placeholder('ADDRESSLINES', addresslines, encode: true)

        deliverylines = generate_deliverylines(order)
        fill_placeholder('DELIVERYLINES', deliverylines, encode: true)

        display_element("scope--#{scope}")
        Mu::log.info "Inline CSS for #{scope} is now #{@inline_css}"

        # Write current state to tmp document
        write_file tmp_path
      end

      # Merge all scoped documents into one PDF document
      merged_pdf = CombinePDF.new
      tmp_paths.each do |path|
        merged_pdf << CombinePDF.load(path)
        # File.delete(path)
      end
      merged_pdf.info[:Title] = @document_title # See https://github.com/boazsegev/combine_pdf/issues/150
      merged_path = "/tmp/#{@resource_id}-delivery-note-merged.pdf"
      merged_pdf.save merged_path

      upload_file merged_path, order[:uri]
      @path
    end

    def generate_deliverylines(order)
      solutions = fetch_invoicelines(order_uri: order[:uri])
      deliverylines = solutions.map do |invoiceline|
        line = "<div class='deliveryline'>"
        line += "  <div class='col col-1'>#{invoiceline[:description]}</div>"
        line += "</div>"
        line
      end
      deliverylines.join
    end
  end
end
