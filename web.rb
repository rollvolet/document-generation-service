require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'better_errors' if development?
require 'json'

require_relative 'lib/visit-report'
require_relative 'lib/offer-document'
require_relative 'lib/invoice-document'

# TODO file cleanup job?

configure :development do
  use BetterErrors::Middleware
  BetterErrors::Middleware.allow_ip! '0.0.0.0/0'
  # you need to set the application root in order to abbreviate filenames within the application:
  BetterErrors.application_root = File.expand_path('..', __FILE__)

  class WickedPdf # monkey patch useful for debugging
    def in_development_mode?
      true
    end

    def print_command(cmd)
      puts cmd
    end
  end

end

post '/documents/visit-report' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  id = json_body['id']
  path = "/tmp/#{id}-bezoekrapport.pdf"

  generate_visit_report(path, json_body)

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

post '/documents/invoice' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  # Workaround to embed visitor initals in the offer object
  data = json_body['invoice']
  data['visit'] = if json_body['visitor'] then { 'visitor' => json_body['visitor'] } else nil end

  id = data['id']
  path = "/tmp/#{id}-factuur.pdf"

  generator = DocumentGenerator::InvoiceDocument.new
  generator.generate(path, data)

  # TODO cleanup temporary created files of WickedPdf
  
  send_file path
end
