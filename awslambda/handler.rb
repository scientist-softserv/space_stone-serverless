# frozen_string_literal: true

require 'json'
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require_relative './derivative_rodeo/lib/derivative_rodeo'

def copy(event:, context:)
  job = get_event_body(event: event)
  # download files to tmp space
  # copy tmp files to ouput_templates
  output_uris = []
  job.each do |input_uri, output_templates|
    tmp_uri = download_to_tmp(input_uri: input_uri)
    output_uris += send_to_locations(tmp_uri: tmp_uri, output_templates: output_templates)
  end
  send_results(output_uris)
end

def split_ocr_thumbnail(event:, context:)
  # {"s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/20121820/20121820.ARCHIVAL.pdf":["s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}"]}
  # split in to pages
  jobs = get_event_body(event: event)
  output_uris = []
  jobs.each do |job|
    job.each do |input_uri, output_templates|
      output_templates.each do |output_template|
        args = {
          input_uris: [input_uri],
          output_target_template: output_template
        }
        output_uris += DerivativeRodeo::Generators::PdfSplitGenerator.new(args).generated_uris
      end
    end
  end
  puts "==== #{output_uris}"
  send_results(output_uris)

  # ocr each individual page
  # thumbnail each invidiual page
end

def ocr(event:, context:)
  event_body = get_event_body(event: event)
  send_results("ocr call #{event_body}")

  #  ocr_uris = DerivativeRodeo::HocrGenerator.new(input_ocr_uris: event_body).generated_uris
  #  send_results(ocr_uris)
end

def thumbnail(event:, context:)
  send_results("thumbnail call #{event}")
end

def get_event_body(event:, return_json: true)
  if event['Records']
    event['Records'].map { |r| JSON.parse(r['body']) }.flatten
  elsif event['isBase64Encoded']
    return_json ? JSON.parse(Base64.decode64(event['body'])) : Base64.decode64(event['body'])
  else
    return_json ? JSON.parse(event['body']) : event['body']
  end
end

def send_results(results)
  {
    statusCode: 200,
    headers: [{ 'Content-Type' => 'application/json' }],
    body: results
  }
end

def download_to_tmp(input_uri:)
  # copy a single input uri down from the server
  args = {
    input_uris: [input_uri],
    output_target_template: 'file:///tmp/{{dir_parts[-1..-1]}}/{{ filename }}'
  }
  DerivativeRodeo::Generators::CopyGenerator.new(args).generated_uris.first
end

def send_to_locations(tmp_uri:, output_templates:)
  output_uris = []
  # copy the locally cached file to its destinations
  output_templates.each do |output_template|
    args = {
      input_uris: [tmp_uri],
      output_target_template: output_template
    }
    output_uris += DerivativeRodeo::Generators::CopyGenerator.new(args).generated_uris
  end
  output_uris
end
