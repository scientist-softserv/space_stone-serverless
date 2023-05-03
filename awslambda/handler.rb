require 'json'
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

def process_csv(event:, context:)
  event_body = get_event_body(event: event, return_json: false)
  send_results("Enqueued X Records")
end

def download(event:, context:)
  download_uris = get_event_body(event: event, return_json: false)
  # TODO deal with output adapter passing bucket/queue
  s3_uris = DerivativeRodeo::DownloadGenerator.new(input_files: download_uris, output_adapter: "s3://#{ENV['AWS_S3_DOWNLOAD_BUCKET']}").generated_uris
  ocr_uris = DerivativeRodeo::MoveGenerator.new(input_files: s3_uris, output_adapter: "sqs://#{ENV['OCR_QUEUE_URL']}").generated_uris
  thumbnail_uris = DerivativeRodeo::MoveGenerator.new(input_files: s3_uris, output_adapter: "sqs://#{ENV['THUMBNAIL_QUEUE_URL']}").generated_uris

  send_results({s3_uris: s3_uris, ocr_queued_count: ocr_uris.size, thumbnail_queued_count: thumbnail_uris.size})
end

def ocr(event:, context:)
  event_body = get_event_body(event: event, return_json: false)
  ocr_uris = DerivativeRodeo::HocrGenerator.new(input_ocr_uris: event_body).generated_uris
  send_results(ocr_uris)
end

def thumbnail(event:, context:)
  send_results('thumbnail call')
end

def get_event_body(event:, return_json: true)
  if event['Records']
    event['Records'].map { |r| JSON.parse(r['body']) }.flatten
  elsif event['isBase64Encoded']
    return_json ? JSON.parse(Base64.decode64(event['body'])) : Base64.decode64(event['body'])
  else
    event['body']
  end
end

def send_results(results)
  {
    statusCode: 200,
    headers: [{ 'Content-Type' => 'application/json' }],
    body: results
  }
end
