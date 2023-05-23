require 'httparty'
url = 'https://v1vzxgta7f.execute-api.us-west-2.amazonaws.com/copy'

workload =   #  for aark_idi
  #    identify files to download
#    identify 0..1 pdfs to split
#    identify thumbnails for a given file
[
  # archive, no reader, text, no obj, thumbnail
  # copy archive, split-ocr-thumbnail archive, copy text for archive, copy thumbnail for archive
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/20/1218/20121820/20121820.ARCHIVAL.pdf': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}',
      'sqs://us-west-2.amazonaws.com/559021623471/space-stone-dev-split-ocr-thumbnail/{{dir_parts[-1..-1]}}/{{ filename }}?template=s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}'
    ]
  },
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/20/1218/20121820/20121820.RAW.txt': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/20121820/20121820.ARCHIVAL.pdf.txt'
    ]
  },
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/20/1218/20121820/20121820.TN.jpg': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/20121820/20121820.ARCHIVAL.pdf.jpg'
    ]
  },
  # archive, no reader, no text, no obj, no thumbnail
  # copy archive, split-ocr-thumbnail archive, thumbnail archive
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/20/1218/20121834/20121834.ARCHIVAL.pdf': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}',
      'sqs://us-west-2.amazonaws.com/559021623471/space-stone-dev-split-ocr-thumbnail/{{dir_parts[-1..-1]}}/{{ filename }}?template=s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}',
      'sqs://us-west-2.amazonaws.com/559021623471/space-stone-dev-thumbnail/{{dir_parts[-1..-1]}}/{{ filename }}?template=s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}'
    ]
  },
  # archive, reader, text, no obj, thumbnail
  # copy archive, copy reader, split-ocr-thumbnail reader, copy text for archive, copy thumbnail for archive, copy text for reader, copy thumbnail for reader
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/22/2501/22250184/22250184.ARCHIVAL.pdf': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}'
    ]
  },
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/20/1218/22250184/22250184.READER.pdf': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}',
      'sqs://us-west-2.amazonaws.com/559021623471/space-stone-dev-split-ocr-thumbnail/{{dir_parts[-1..-1]}}/{{ filename }}?template=s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}'
    ]
  },
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/22/2501/22250184/22250184.RAW.txt': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/22250184/22250184.READER.pdf.txt',
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/22250184/22250184.ARCHIVAL.pdf.txt'
    ]
  },
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/22/2501/22250184/22250184.TN.jpg': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/22250184/22250184.READER.pdf.jpg',
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/22250184/22250184.ARCHIVAL.pdf.jpg'
    ]
  },
  # no archive, no reader, no text, obj, thumbnail
  # copy obj, copy thumbnail
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/20/0000/20000026/20000026.TN.jpg': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}'
    ]
  },
  # no archive, no reader, no text, obj, no thumbnail
  # copy obj, create thumbnail for obj
  {
    'https://adl-ebstore-repo.s3.amazonaws.com/20/0000/20000026/20000026.TN.jpg': [
      's3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}',
      'sqs://us-west-2.amazonaws.com/559021623471/space-stone-dev-thumbnail/{{dir_parts[-1..-1]}}/{{ filename }}?template=s3://space-stone-dev-preprocessedbucketf21466dd-bxjjlz4251re.s3.us-west-1.amazonaws.com/{{dir_parts[-1..-1]}}/{{ filename }}'
    ]
  },
]

if ENV.fetch('LOCAL', nil)
  event = %x{sls generate-event --type aws:apiGateway --body '#{JSON.generate(workload[0])}'}
  puts %x{sls invoke local --function copy --data '#{event}'}
else
  HTTParty.post(url, body: JSON.generate(workload[0]), headers: { 'Content-Type' => 'application/json' })
end
