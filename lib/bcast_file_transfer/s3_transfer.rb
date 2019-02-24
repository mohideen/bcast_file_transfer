require 'aws-sdk-s3'
require 'json'
require 'fileutils'
require 'logger'
require 'erb'
require 'yaml'

module BcastFileTransfer
  # Library class that holds individual operation steps for use by scripts
  class S3Transfer
    include Logging

    # Determine files that need to be transferred
    def files_to_transfer(destination_bucket, src_dir) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      dest_bucket = destination_bucket['bucket']
      dest_region = destination_bucket['region']
      src_dir_path = Pathname.new(src_dir)
      src_dir_list = Dir[src_dir + '**/*/']
      src_file_list = Dir[src_dir + '**/*.mp3']
      dest_file_list = []
      s3 = Aws::S3::Client.new(region: dest_region)
      result = nil

      # Check S3 for matching files for each subfolder in source path (e.g. 09-05-2016/)
      src_dir_list.each do |d| # rubocop:disable Metrics/BlockLength
        dest_prefix = S3TransferHelper.get_dest_prefix(destination_bucket, d)
        dest_path = Pathname.new(dest_prefix)
        check_prefix = dest_prefix + Pathname.new(d).relative_path_from(src_dir_path).to_s
        begin
          logger.debug("Listing files in s3://#{dest_bucket}/#{check_prefix}")
          result = s3.list_objects_v2(bucket: dest_bucket, prefix: check_prefix)
          loop do
            if result.successful?
              result.contents.each do |obj|
                break unless obj.key.end_with?('.mp3')
                rel_path = Pathname.new(obj.key).relative_path_from(dest_path).to_s
                local_path = src_dir_path.to_s + rel_path
                logger.debug("Comparing Etags of #{obj.key} to #{local_path}")
                # Remove the file from transfer file list if Source and S3 checksum (etag) matches
                etag_matched = S3TransferHelper.etag_match?(local_path, S3TransferHelper.unquote_etag(obj.etag))
                src_file_list.delete(local_path) if etag_matched
                logger.debug("Etag Matched: #{etag_matched}")
              end
            else
              logger.error('Cannot list S3 bucket!')
            end
            break unless result.next_continuation_token
            result = s3.list_objects_v2(bucket: dest_bucket, continuation_token: result.next_continuation_token)
          end
        rescue => ex # rubocop:disable Style/RescueStandardError
          logger.error('Comparison failure! Exception when listing S3 bucket: ' + ex.message)
        end
      end

      src_file_list.each do |file|
        rel_path = Pathname.new(file).relative_path_from(src_dir_path).to_s
        dest_file_list << rel_path
      end
      ComparisonResult.new(destination_bucket['path'], src_dir, result, dest_file_list)
    end

    # Copies the given file to the destination bucket.
    def transfer_file(destination_bucket, src_dir, filename) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      dest_bucket = destination_bucket['bucket']
      dest_prefix = S3TransferHelper.get_dest_prefix(destination_bucket, filename)
      dest_region = destination_bucket['region']
      src_file_path = src_dir + filename
      dest_file_path = dest_prefix + filename

      logger.info "Transferring #{src_file_path} to s3://#{dest_bucket}/#{dest_file_path}"
      s3 = Aws::S3::Resource.new(region: dest_region)
      obj = s3.bucket(dest_bucket).object(dest_file_path)
      logger.debug "Created s3://#{dest_bucket}/#{dest_file_path}! Uploading file..."
      result = obj.upload_file(src_file_path, multipart_threshold: 4 * 1024 * 1024)
      logger.debug 'Completed upload!' if result
      logger.error "Error uploading #{src_file_path} to s3://#{dest_bucket}/#{dest_file_path}" unless result

      TransferResult.new(dest_prefix, src_dir, filename, S3UploadResult.new(dest_file_path, result))
    end
  end
end
