require_relative '../handler'
require 'byebug'

describe "handler" do
  describe 'process_csv' do
    it 'when success' do
      event_json = JSON.parse(File.read(File.join(__dir__, 'fixtures', 'events', 'http.json')))
      event_json['body'] = Base64.encode64(File.read(File.join(__dir__, 'fixtures', 'processing_list.csv')))
      response = process_csv(event: event_json, context: {})
      expect(response[:statusCode]).to eq 200
    end
  end

  describe 'ocr' do
    it 'when success' do
      response = ocr(event: {}, context: {})
      expect(response[:statusCode]).to eq 200
    end
  end
end
