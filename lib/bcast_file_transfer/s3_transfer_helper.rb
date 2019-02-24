module BcastFileTransfer
  # Helper methods for S3 transfer
  class S3TransferHelper
    class << self
      # Get the S3 prefix based on configuration and provided file name
      def get_dest_prefix(bucket, file)
        prefix = bucket['path']
        sub_prefix = bucket['sub_prefix']
        prefix += get_year_substring(file) + '/' if %w[year year_month].include?(sub_prefix)
        prefix += get_month_substring(file) + '/' if sub_prefix == 'year_month'
        prefix
      end

      def get_year_substring(filename)
        # Known patterns: WTOP_PGM_60_09-03-2016_0000.mp3, WTOP_09-07-2018_0000.mp3, 09-05-2016/
        filename.end_with?('mp3') ? filename[-13..-10] : filename[-5..-2]
      end

      def get_month_substring(filename)
        # Known patterns: WTOP_PGM_60_09-03-2016_0000.mp3, WTOP_09-07-2018_0000.mp3, 09-05-2016/
        filename.end_with?('mp3') ? filename[-19..-18] : filename[-11..-10]
      end

      def unquote_etag(etag)
        etag[1..-2]
      end

      # Verify if the local files etag (MD5 checksum) matches the provided etag.
      def etag_match?(file, etag)
        return false unless File.exist?(file)
        split = etag.split('-')
        file_etag = split.length == 1 ? Digest::MD5.hexdigest(File.read(file)) : multipart_etag(file, split[1])
        etag == file_etag
      end

      # MD5 Checksum of the aggregated checksums of individual parts (byte-chunks) of a file
      def multipart_etag(file, num_parts) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        md5 = Digest::MD5.new
        file_size_bytes = File.size(file)
        file_size_mb = (file_size_bytes / 1024 / 1024)
        file_part_size = (file_size_mb / num_parts.to_f).ceil * 1024 * 1024
        file_descriptor = IO.sysopen(file)
        io = IO.new(file_descriptor)
        checksums = []
        count = 0
        begin
          loop do
            chunk = io.sysread(file_part_size)
            count += 1
            md5 << chunk
            checksums << md5.hexdigest
            md5.reset
          end
        rescue EOFError # rubocop:disable Lint/HandleExceptions
          # Finished processing the file
        end
        io.close
        md5 << [checksums.join].pack('H*')
        md5.hexdigest + "-#{count}"
      end
    end
  end
end
