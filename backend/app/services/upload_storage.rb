require "aws-sdk-s3"

class UploadStorage
  attr_reader :client, :bucket

  def initialize
    @bucket = ENV.fetch("S3_BUCKET", "resilienceatlas")
    @client = Aws::S3::Client.new(region: ENV.fetch("AWS_REGION", "us-east-1"))
  end

  def head(key)
    client.head_object(bucket: bucket, key: key)
  end

  def download(key, path)
    client.get_object(bucket: bucket, key: key, response_target: path.to_s)
  end

  def upload_file(path, key, content_type:)
    Aws::S3::Object.new(bucket_name: bucket, key: key, client: client)
      .upload_file(path.to_s, content_type: content_type)
  end

  def abort(data_import)
    return if data_import.upload_id.blank?
    client.abort_multipart_upload(bucket: bucket, key: data_import.s3_key, upload_id: data_import.upload_id)
  rescue Aws::S3::Errors::NoSuchUpload
    Rails.logger.info "[Upload #{data_import.id}] Multipart upload already closed"
  end
end
