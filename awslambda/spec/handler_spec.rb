# frozen_string_literal: true

require_relative '../handler'
require 'byebug'

require 'spec_support/aws_s3_faux_bucket'
require 'spec_support/aws_sqs_faux_client'

module Fixtures
  ##
  # A helper function for encoding body into an expected AWS serverless event format.
  def self.event_json_for(*body, encode: true)
    event_json = JSON.parse(File.read(File.join(__dir__, 'fixtures', 'events', 'http.json')))
    body = JSON.generate(body)
    if encode
      event_json['isBase64Encoded'] = true
      event_json['body'] = Base64.encode64(body)
    else
      event_json['isBase64Encoded'] = false
      event_json['body'] = body
    end
    event_json
  end

  ##
  # Instead of using the http(s) location format, we can use the file location and avoid https
  # requests for getting files.
  def self.file_location_for(filename)
    "file://#{File.join(__dir__, 'fixtures', 'files', filename)}"
  end
end

describe 'handler' do
  before do
    DerivativeRodeo::StorageLocations::S3Location.use_actual_s3_bucket = false
    DerivativeRodeo::StorageLocations::SqsLocation.use_real_sqs = false
  end

  describe 'process_csv' do
    xit 'when success' do
      event_json = Fixtures.event_json_for(File.read(File.join(__dir__, 'fixtures', 'processing_list.csv')),
                                           encode: false)
      response = process_csv(event: event_json, context: {})
      expect(response[:statusCode]).to eq 200
    end
  end

  describe '#copy' do
    it 'processes each key/value pair, copying the key to each of the given values' do
      s3_host_name = 'space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com'
      event_json = Fixtures.event_json_for({ Fixtures.file_location_for('minimal-2-page.pdf') => [
                                             "s3://#{s3_host_name}/{{dir_parts[-1..-1]}}/{{ filename }}",
                                             'sqs://us-west-2.amazonaws.com/559021623471/space-stone-dev-split-ocr-thumbnail/{{dir_parts[-1..-1]}}/{{ filename }}?template=s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}'
                                           ] }, {
                                             Fixtures.file_location_for('minimal-2-page.txt') => [
                                               "s3://#{s3_host_name}/{{dir_parts[-1..-1]}}/minimal-2-page.pdf.txt"
                                             ]
                                           })
      response = copy(event: event_json, context: {})

      # TODO: as of <2023-05-31 Wed> we cannot peak into the configured faux bucket; because that
      # bucket is only instantiated as part of the underlying location object (which we do not
      # expose directly).
      expect(response[:body].size).to eq(3)
      expect(response[:body]).to match_array(["s3://#{s3_host_name}/files/minimal-2-page.pdf",
                                              'sqs://us-west-2.amazonaws.com/559021623471/space-stone-dev-split-ocr-thumbnail/files/minimal-2-page.pdf?template=s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}',
                                              "s3://#{s3_host_name}/files/minimal-2-page.pdf.txt"])
    end
  end

  describe '#ocr' do
    it 'will enqueue three jobs: word coordinates, plain text and alto xml' do
      event_json = Fixtures.event_json_for({ Fixtures.file_location_for('123/ocr_color.tiff') => [
                                             's3://s3.com/{{dir_parts[-1..-1]}}/{{ filename }}'
                                           ] })
      response = ocr(event: event_json, context: {}, env: {
                       'S3_BUCKET_NAME' => 'bucket',
                       'WORD_COORDINATES_QUEUE_URL' => 'sqs://word_coords',
                       'PLAIN_TEXT_QUEUE_URL' => 'sqs://text',
                       'ALTO_XML_QUEUE_URL' => 'sqs://alto'
                     })

      expect(response[:body]).to eq [
        "s3://s3.com/123/ocr_color.tiff",
        "sqs://word_coords/123/ocr_color.coordinates.json?template=s3://bucket.s3.us-east-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ basename }}.coordinates.json",
        "sqs://text/123/ocr_color.plain_text.txt?template=s3://bucket.s3.us-east-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ basename }}.plain_text.txt",
        "sqs://alto/123/ocr_color.alto.xml?template=s3://bucket.s3.us-east-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ basename }}.alto.xml"
      ]
    end

    xit 'when success' do
      response = ocr(event: {}, context: {})
      expect(response[:statusCode]).to eq 200
    end
  end

  describe "#split_ocr_thumbnail" do
    it "splits the pdf into its pages and enqueues that many ocr and thumbnail jobs" do
      event_json = Fixtures.event_json_for({ Fixtures.file_location_for("minimal-2-page.pdf") => [
                                               "s3://s3.com/{{dir_parts[-1..-1]}}/{{ filename }}"] })
      response = split_ocr_thumbnail(event: event_json, context: {}, env: { 'S3_BUCKET_NAME' => 'bucket', 'OCR_QUEUE_URL' => 'sqs://ocr', 'THUMBNAIL_QUEUE_URL' => 'sqs://thumbnail' })
      expect(response[:body]).to eq [
        "s3://s3.com/pages/minimal-2-page-1.tiff",
        "s3://s3.com/pages/minimal-2-page-2.tiff",
        "sqs://ocr/pages/minimal-2-page-1.hocr?template=s3://bucket.s3.us-east-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ basename }}.hocr",
        "sqs://ocr/pages/minimal-2-page-2.hocr?template=s3://bucket.s3.us-east-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ basename }}.hocr",
        "sqs://thumbnail/pages/minimal-2-page-1.thumbnail.jpeg?template=s3://bucket.s3.us-east-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ basename }}.thumbnail.jpeg",
        "sqs://thumbnail/pages/minimal-2-page-2.thumbnail.jpeg?template=s3://bucket.s3.us-east-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ basename }}.thumbnail.jpeg"
      ]
    end
  end
end
