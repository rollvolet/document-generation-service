require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'pry' if development?
require 'better_errors' if development?
require 'json'

require_relative 'lib/visit-report'

# TODO file cleanup job?

configure :development do
  use BetterErrors::Middleware
  BetterErrors::Middleware.allow_ip! '0.0.0.0/0'
  # you need to set the application root in order to abbreviate filenames within the application:
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

post '/documents/visit-report' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  id = json_body['id']
  path = "/tmp/#{id}-bezoekrapport.pdf"

  generate_visit_report(path, json_body)

  send_file path
end

