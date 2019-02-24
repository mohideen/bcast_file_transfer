require 'rsync'
require 'json'
require 'fileutils'
require 'logger'
require 'erb'
require 'yaml'

module BcastFileTransfer
  # Library class that holds individual operation steps for use by scripts
  class RsyncTransfer
    include Logging

    # Determine files that need to be transferred
    def files_to_transfer(destination_server, src_dir) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      dest_server = destination_server['server']
      dest_directory = destination_server['path']
      dest_username = destination_server['username']

      rsync_options = ['--archive', '--dry-run', '--itemize-changes']

      logger.debug "rsync #{rsync_options.join(' ')} #{src_dir} #{dest_username}@#{dest_server}:#{dest_directory}"

      transfer_files = []
      result = Rsync.run(src_dir, "#{dest_username}@#{dest_server}:#{dest_directory}", rsync_options)
      if result.success?
        result.changes.select { |c| c.file_type == :file && c.update_type == :sent }.each do |change|
          transfer_files << change.filename
        end
      else
        logger.error(
          "Comparison failure: exitcode: #{result.exitcode}, " \
          "error: #{result.error}, " \
          "dest_server: #{dest_server}, " \
          "dest_directory: #{dest_directory}"
        )
      end

      ComparisonResult.new(dest_directory, src_dir, result, transfer_files)
    end

    # Copies the given file to the destination server.
    def transfer_file(destination_server, src_dir, filename) # rubocop:disable Metrics/AbcSize
      dest_server = destination_server['server']
      dest_directory = destination_server['path']
      dest_username = destination_server['username']

      # Append "./" between src_dir and filename. This used by the rsync
      # "relative" functionlity to where the path to starts when transferring
      # the file.
      src_file_path = src_dir + './' + filename

      rsync_options = ['--archive', '--itemize-changes', '--relative']

      logger.info "Transferring #{src_file_path} to #{dest_server}:#{dest_directory}"
      logger.debug "\trsync #{rsync_options.join(' ')} #{src_file_path} #{dest_username}@#{dest_server}:#{dest_directory}" # rubocop:disable Metrics/LineLength

      result = Rsync.run(src_file_path, "#{dest_username}@#{dest_server}:#{dest_directory}", rsync_options)

      logger.error "Error transferring #{filename} to #{dest_server}:#{dest_directory}" unless result.success?

      TransferResult.new(dest_directory, src_dir, filename, result)
    end
  end
end
