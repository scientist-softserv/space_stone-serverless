# frozen_string_literal: true

require 'json'
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require_relative './derivative_rodeo/lib/derivative_rodeo'

########################################################################################################################
# @!group Handlers
# See README for more clarification


##
# @param event [String] We'll convert, via {#get_event_body}, the given :event.  The results of the
#        call to {#get_event_body} is a hash with keys that are strings and values are an array of
#        strings.
# @param context [Object]
# @return [Hash<Symbol, Object>] from {#response_body_for}
# @todo TODO: Refactor to maybe use #handle method?
def copy(event:, context:)
  jobs = get_event_body(event: event)
  output_uris = []
  jobs.each do |job|
    job.each do |input_uri, output_location_templates|
      tmp_uri = download_to_tmp(input_uri: input_uri)
      output_uris += send_to_locations(tmp_uris: [tmp_uri], output_location_templates: output_location_templates)
    end
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
def split_ocr_thumbnail(event:, context:, env: ENV)
  # {"s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/20121820/20121820.ARCHIVAL.pdf":["s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}"]}
  # split in to pages
  handle(generator: DerivativeRodeo::Generators::PdfSplitGenerator, event: event, context: context) do |output_uris|
    s3_url = s3_name_to_url(bucket_name: env['S3_BUCKET_NAME'])
    output_location_templates = [
      queue_url_to_rodeo_url(queue_url: env['OCR_QUEUE_URL'], s3_url_domain: s3_url, template_tail: "{{dir_parts[-1..-1]}}/{{ basename }}.#{DerivativeRodeo::Generators::HocrGenerator.output_extension}"),
      queue_url_to_rodeo_url(queue_url: env['THUMBNAIL_QUEUE_URL'], s3_url_domain: s3_url, template_tail: "{{dir_parts[-1..-1]}}/{{ basename }}.#{DerivativeRodeo::Generators::ThumbnailGenerator.output_extension}")
    ]
    send_to_locations(tmp_uris: output_uris, output_location_templates: output_location_templates)
  end
end

def ocr(event:, context:, env: ENV)
  handle(generator: DerivativeRodeo::Generators::HocrGenerator, event: event, context: context) do |output_uris|
    s3_url = s3_name_to_url(bucket_name: env['S3_BUCKET_NAME'])
    output_location_templates = [
      queue_url_to_rodeo_url(queue_url: env['WORD_COORDINATES_QUEUE_URL'], s3_url_domain: s3_url, template_tail: "{{dir_parts[-1..-1]}}/{{ basename }}.#{DerivativeRodeo::Generators::WordCoordinatesGenerator.output_extension}"),
      queue_url_to_rodeo_url(queue_url: env['PLAIN_TEXT_QUEUE_URL'], s3_url_domain: s3_url, template_tail: "{{dir_parts[-1..-1]}}/{{ basename }}.#{DerivativeRodeo::Generators::PlainTextGenerator.output_extension}"),
      queue_url_to_rodeo_url(queue_url: env['ALTO_XML_QUEUE_URL'], s3_url_domain: s3_url, template_tail: "{{dir_parts[-1..-1]}}/{{ basename }}.#{DerivativeRodeo::Generators::AltoGenerator.output_extension}"),
    ]
    send_to_locations(tmp_uris: output_uris, output_location_templates: output_location_templates)
  end
end

def thumbnail(event:, context:)
  handle(generator: DerivativeRodeo::Generators::ThumbnailGenerator, event: event, context: context)
end

def word_coordinates(event:, context:)
  handle(generator: DerivativeRodeo::Generators::WordCoordinatesGenerator, event: event, context: context)
end

def plain_text(event:, context:)
  handle(generator: DerivativeRodeo::Generators::PlainTextGenerator, event: event, context: context)
end

def alto_xml(event:, context:)
  handle(generator: DerivativeRodeo::Generators::AltoGenerator, event: event, context: context)
end

# @!endgroup Handlers
########################################################################################################################

########################################################################################################################
# @!group Helpers
# All other methods below are non-handlers (helpers if you will)

def handle(generator:, event:, context:)
  jobs = get_event_body(event: event)
  output_uris = []
  jobs.each do |job|
    job.each do |input_uri, output_templates|
      output_templates.each do |output_template|
        args = {
          input_uris: [input_uri],
          output_location_template: output_template
        }
        output_uris += generator.new(**args).generated_uris
      end
    end
  end
  output_uris += yield output_uris if block_given?
  response_body_for(output_uris)
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
  events = if event['Records']
             event['Records'].map { |r| JSON.parse(r['body']) }.flatten
           elsif event['isBase64Encoded']
             parse_body_as_json ? JSON.parse(Base64.decode64(event['body'])) : Base64.decode64(event['body'])
           else
             parse_body_as_json ? JSON.parse(event['body']) : event['body']
           end
  puts "Events: #{events}"
  events
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
  # Get a log message for the output, especially useful if dealing with SQS queues
  puts results.inspect
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
# @param tmp_uris [Array<Object>]
# @param output_location_templates [Array<String>]
# @return [Array<String>]
def send_to_locations(tmp_uris:, output_location_templates:)
  output_location_templates.flat_map do |output_template|
    DerivativeRodeo::Generators::CopyGenerator.new(
      input_uris: tmp_uris,
      output_location_template: output_template
    ).generated_uris
  end
end

##
# @api private
#
# Convert SQS url from Amazons format to Derivative Rodeo's format. Add template information and s3 destination
#
# @example
# https://sqs.us-west-2.amazonaws.com/AID/space-stone-dev-ocr =>
# sqs://us-west-2.amazonaws.com/AID/space-stone-dev-ocr/{{dir_parts[-1..-1]}}/{{ basename }}?template=s3://BUCKET.s3.REGION.amazonaws.com/{{dir_parts[-1..-1]}}/{{ basename }}
#
# @param queue_url [String]
# @param s3_url_domain [String] - the s3://BUCKET.s3.REGION.amazonaws.com part of the url
# @param template_tail [String] - the directory / filename parts of both the sqs and s3 uris.
# @return [String]
def queue_url_to_rodeo_url(queue_url:, s3_url_domain: nil, template_tail: nil, source_path: "/{{dir_parts[-1..-1]}}/{{ filename }}")
  url = queue_url.gsub('https://sqs.', 'sqs://')

  url = File.join(url, source_path) if source_path
  url += "?template=#{s3_url_domain}/#{template_tail}" if s3_url_domain
end

##
# @api private
#
# Get the S3 url for the given bucket name
#
# @param bucket_name [String]
# @return [String]
def s3_name_to_url(bucket_name:)
  DerivativeRodeo::StorageLocations::S3Location.adapter_prefix(bucket_name: bucket_name)
end

# @!endgroup Helpers
########################################################################################################################
