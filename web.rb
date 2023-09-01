require 'combine_pdf'
require 'facets'

require_relative 'lib/visit-report'
require_relative 'lib/visit-summary'
require_relative 'lib/intervention-report'
require_relative 'lib/offer-document'
require_relative 'lib/order-document'
require_relative 'lib/delivery-note'
require_relative 'lib/production-ticket'
require_relative 'lib/invoice-document'
require_relative 'lib/deposit-invoice-document'
require_relative 'lib/vat-certificate'

# TODO file cleanup job?

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

post '/documents/visit-summary' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  path = "/tmp/#{Mu.generate_uuid}-bezoekrapport.pdf"

  generator = DocumentGenerator::VisitSummary.new
  generator.generate(path, json_body)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/requests/:id/documents' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  generator = DocumentGenerator::VisitReport.new id: params['id']
  path = generator.generate

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/documents/intervention-report' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  data = json_body['intervention']
  id = data['id']
  path = "/tmp/#{id}-interventierapport.pdf"

  generator = DocumentGenerator::InterventionReport.new
  generator.generate(path, data)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/documents/offer' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  # Workaround to embed visitor initals in the offer object
  data = json_body['offer']
  if data['request']
    data['request']['visit'] = { 'visitor' => json_body['visitor'] }
  end

  id = data['id']
  path = "/tmp/#{id}-offerte.pdf"

  generator = DocumentGenerator::OfferDocument.new
  generator.generate(path, data)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/documents/order' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  # Workaround to embed visitor initals in the offer object
  data = json_body['order']
  if data['offer'] and data['offer']['request']
    data['offer']['request']['visit'] = { 'visitor' => json_body['visitor'] }
  end

  id = data['id']
  path = "/tmp/#{id}-bestelbon.pdf"

  generator = DocumentGenerator::OrderDocument.new
  generator.generate(path, data)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/documents/delivery-note' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  # Workaround to embed visitor initals in the offer object
  data = json_body['order']
  if data['offer'] and data['offer']['request']
    data['offer']['request']['visit'] = { 'visitor' => json_body['visitor'] }
  end

  id = data['id']
  path = "/tmp/#{id}-leveringsbon.pdf"
  generator = DocumentGenerator::DeliveryNote.new
  generator.generate(path, data)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/documents/production-ticket' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  data = json_body['order']
  # Workaround to embed visitor initals in the offer object
  if data['offer'] and data['offer']['request']
    data['offer']['request']['visit'] = { 'visitor' => json_body['visitor'] }
  end

  id = data['id']
  path = "/tmp/#{id}-productiebon.pdf"
  generator = DocumentGenerator::ProductionTicket.new
  generator.generate(path, data)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/documents/production-ticket-watermark' do
  if params['file']
    tempfile = params['file'][:tempfile]
    random = (rand * 100000000).to_i
    production_ticket_path = "/tmp/#{random}-production-ticket.pdf"
    FileUtils.copy(tempfile.path, production_ticket_path)

    watermark_path = ENV['PRODUCTION_TICKET_WATERMARK_NL'] || '/watermarks/productiebon-nl.pdf'
    watermark = CombinePDF.load(watermark_path).pages[0]

    begin
      pdf = CombinePDF.load production_ticket_path, allow_optional_content: true
      pdf.pages.each { |page| page << watermark }
      path = "/tmp/#{random}-production-ticket-watermark.pdf"
      pdf.save path

      # TODO cleanup temporary created files

      send_file path
    rescue CombinePDF::ParsingError
      # log.warn "Unable to parse incoming production ticket PDF and add a watermark. Just returning the original production ticket instead."
      send_file production_ticket_path
    end
  else
    halt 400, { title: 'File is required' }
  end
end

post '/invoices/:id/documents' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  id = params['id']
  data = json_body['data']
  language = data['attributes']['language']

  generator = DocumentGenerator::InvoiceDocument.new id: id, language: language
  path = generator.generate(data)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/deposit-invoices/:id/documents' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  id = params['id']
  data = json_body['data']
  language = data['attributes']['language']

  generator = DocumentGenerator::DepositInvoiceDocument.new id: id, language: language
  path = generator.generate(data)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end

post '/documents/certificate' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  data = json_body['invoice']

  id = data['id']
  path = "/tmp/#{id}-attest.pdf"

  generator = DocumentGenerator::VatCertificate.new
  generator.generate(path, data)

  # TODO cleanup temporary created files of WickedPdf

  send_file path
end
