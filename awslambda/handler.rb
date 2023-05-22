# frozen_string_literal: true

require 'json'
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require_relative './derivative_rodeo/lib/derivative_rodeo'

##
# @param event [String] We'll convert, via {#get_event_body}, the given :event.  The results of the
#        call to {#get_event_body} is a hash with keys that are strings and values are an array of
#        strings.
# @param context [Object]
# @return [Hash<Symbol, Object>] from {#response_body_for}
def copy(event:, context:)
  input_uris_and_templates = get_event_body(event: event)
  output_uris = []
  input_uris_and_templates.each do |input_uri, output_location_templates|
    tmp_uri = download_to_tmp(input_uri: input_uri)
    output_uris += send_to_locations(tmp_uri: tmp_uri, output_location_templates: output_location_templates)
  end
  response_body_for(output_uris)
end

##
# The purpose of this job is to handle the PDF-level derivatives.  Which involves:
#
# - creating the PDF level thumbnail
# - creating one image per page of each given PDF
#
# @param event [String] We'll convert, via {#get_event_body}, the given :event.  The results of the
#        call to {#get_event_body} is a hash with keys that are strings and values are an array of
#        strings.
# @param context [Object]
# @return [Hash<Symbol, Object>] from {#response_body_for}
def split_ocr_thumbnail(event:, context:)
  # split in to pages
  puts "split_ocr_thumbnail #{event}"
  input_uris_and_template = get_event_body(event: event)
  output_uris = []

  # TODO: We have PDF Splitting but we need thumbnails.
  input_uris_and_template.each do |input_uri, output_location_template|
    # TODO: Given the output_uris are the URIs to each image of each page of each PDF, should we
    # now begin processing those images within this handler invocation?  If not, how do we enqueue
    # this work?
    output_uris += DerivativeRodeo::Generators::PdfSplitGenerator.new(
      input_uris: input_uri,
      output_location_template: output_location_template).generated_uris
    # TODO: Should we add the yet to be created DerivativeRodeo::Generators::Thumbnail call here?
  end

  # TODO: Should we be returning the thumbnail URIs as well as the PDF pages uris?
  response_body_for(output_uris)

  # TODO: Is the comments after the response_body_for significant?  My read is that the
  # response_body_for should always be last

  # ocr each individual page
  # thumbnail each invidiual page
end

def ocr(event:, context:)
  # TODO: Get working
  event_body = get_event_body(event: event)
  response_body_for("ocr call #{event_body}")

  #  ocr_uris = DerivativeRodeo::HocrGenerator.new(input_ocr_uris: event_body).generated_uris
  #  send_results(ocr_uris)
end

def thumbnail(event:, context:)
  # TODO: Get working
  response_body_for("thumbnail call #{event}")
end

##
# @api private
#
# Parse the given :event and return a
#
# @param event [Hash<String,String>]
# @param parse_body_as_json [Boolean] when true parse the given event's body keys as JSON.
#
# @return [String, Hash] the return value depends on whether we're returning parsed JSON or the raw document
def get_event_body(event:, parse_body_as_json: true)
  if event['Records']
    event['Records'].map { |r| JSON.parse(r['body']) }.flatten
  elsif event['isBase64Encoded']
    parse_body_as_json ? JSON.parse(Base64.decode64(event['body'])) : Base64.decode64(event['body'])
  else
    parse_body_as_json ? JSON.parse(event['body']) : event['body']
  end
end

##
# @api private
#
# Create the response body for a handled event.
#
# @param results [Object]
# @param status_code [Integer]
# @param headers [Array<Hash<String, String>>]
#
# @return [Hash<Symbol,Object>]
def response_body_for(results, status_code: 200, headers: [{ 'Content-Type' => 'application/json' }])
  {
    statusCode: status_code,
    headers: headers,
    body: results
  }
end


##
# @api private
#
# Copy the given :input_uri to an output location (as described in the given
# :output_location_template).
#
# @param input_uri [String]
# @param output_location_template [String]
# @return [String] an output_uri, as described by the :output_location_template
def download_to_tmp(input_uri:, output_location_template: 'file:///tmp/{{dir_parts[-1..-1]}}/{{ filename }}')
  DerivativeRodeo::Generators::CopyGenerator.new(
    input_uris: [input_uri],
    output_location_template: output_location_template
  ).generated_uris.first
end

##
# @api private
#
# Copy the the locally cached file (at the given :tmp_uri location) to its destinations based on the
# given :output_location_templates.  Return the "generated" locations.
#
# @param tmp_uri [Object]
# @param output_location_templates [Array<String>]
# @return [Array<String>]
def send_to_locations(tmp_uri:, output_location_templates:)
  output_location_templates.flat_map do |output_template|
    output_uris += DerivativeRodeo::Generators::CopyGenerator.new(
      input_uris: [tmp_uri],
      output_location_template: output_template
    ).generated_uris
  end
end
