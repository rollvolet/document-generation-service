require 'combine_pdf'
require 'facets'

require_relative 'lib/visit-report'
require_relative 'lib/intervention-report'
require_relative 'lib/offer-document'
require_relative 'lib/order-document'
require_relative 'lib/delivery-note'
require_relative 'lib/production-ticket'
require_relative 'lib/invoice-document'
require_relative 'lib/deposit-invoice-document'

configure :development do
  class WickedPdf # monkey patch useful for debugging
    def in_development_mode?
      true
    end

    def print_command(cmd)
      puts cmd
    end
  end

end

before do
  session = session_id_header request
  @user = fetch_user_for_session session
end

post '/requests/:id/documents' do
  generator = DocumentGenerator::VisitReport.new id: params['id'], user: @user
  path = generator.generate

  send_file path
end

post '/interventions/:id/documents' do
  generator = DocumentGenerator::InterventionReport.new id: params['id'], user: @user
  path = generator.generate

  send_file path
end

post '/offers/:id/documents' do
  data = @json_body['data']
  language = data['attributes']['language']

  generator = DocumentGenerator::OfferDocument.new id: params['id'], language: language, user: @user
  path = generator.generate

  send_file path
end

post '/orders/:id/documents' do
  data = @json_body['data']
  language = data['attributes']['language']

  generator = DocumentGenerator::OrderDocument.new id: params['id'], language: language, user: @user
  path = generator.generate

  send_file path
end

post '/orders/:id/delivery-notes' do
  data = @json_body['data']
  language = data['attributes']['language']

  generator = DocumentGenerator::DeliveryNote.new id: params['id'], language: language, user: @user
  path = generator.generate

  send_file path
end

post '/deposit-invoices/:id/documents' do
  data = @json_body['data']
  language = data['attributes']['language']

  generator = DocumentGenerator::DepositInvoiceDocument.new id: params['id'], language: language, user: @user
  path = generator.generate(data)

  send_file path
end

post '/invoices/:id/documents' do
  data = @json_body['data']
  language = data['attributes']['language']

  generator = DocumentGenerator::InvoiceDocument.new id: params['id'], language: language, user: @user
  path = generator.generate(data)

  send_file path
end

post '/cases/:id/production-ticket-templates' do
  generator = DocumentGenerator::ProductionTicket.new id: params['id'], user: @user
  path = generator.generate

  send_file path
end

post '/cases/:id/watermarked-production-tickets' do
  if params['file']
    uploaded_file = params['file'][:tempfile]
    random = (rand * 100000000).to_i
    production_ticket_path = "/tmp/#{random}-production-ticket.pdf"
    FileUtils.copy(uploaded_file.path, production_ticket_path)

    watermark_path = ENV['PRODUCTION_TICKET_WATERMARK_NL'] || '/watermarks/productiebon-nl.pdf'
    watermark = CombinePDF.load(watermark_path).pages[0]

    begin
      pdf = CombinePDF.load production_ticket_path, allow_optional_content: true
      pdf.pages.each { |page| page << watermark }
      path = "/tmp/#{random}-production-ticket-watermark.pdf"
      pdf.save path

      send_file path
    rescue CombinePDF::ParsingError
      # log.warn "Unable to parse incoming production ticket PDF and add a watermark. Just returning the original production ticket instead."
      send_file production_ticket_path
    end
  else
    halt 400, { title: 'File is required' }
  end
end
