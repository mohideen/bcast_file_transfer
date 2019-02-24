require 'rsync'
require 'json'
require 'fileutils'
require 'logger'
require 'erb'
require 'yaml'

module BcastFileTransfer
  # Library class that holds individual operation steps for use by scripts
  class BcastFileTransfer
    include Logging

    # Determine files that need to be transferred
    def files_to_transfer(type, destination, src_dir)
      if type == 'server'
        @rsync_transfer = RsyncTransfer.new
        @rsync_transfer.files_to_transfer(destination, src_dir)
      else
        @s3_transfer = S3Transfer.new
        @s3_transfer.files_to_transfer(destination, src_dir)
      end
    end

    # Copies the given file to the destination .
    def transfer_file(type, destination, src_dir, filename)
      if type == 'server'
        @rsync_transfer = RsyncTransfer.new
        @rsync_transfer.transfer_file(destination, src_dir, filename)
      else
        @s3_transfer = S3Transfer.new
        @s3_transfer.transfer_file(destination, src_dir, filename)
      end
    end

    # Removes any empty subdirectories in the given directory.
    def prune_empty_subdirectories(dir)
      prune_results = []
      Dir[dir + '**/'].reverse_each do |d|
        next if d == dir # Skip directory itself
        next unless Dir.entries(d).sort == %w[. ..]

        logger.debug "Pruning empty subdirectory: #{d}"
        Dir.rmdir d
        prune_results << PruneResult.new(d)
      end
      prune_results
    end

    # Moves the list of given files from the given src_dir directory to the
    # given transfer directory
    def move_files_after_transfer(files_to_move, src_dir, succesful_transfer_dir)
      move_results = []
      files_to_move.each do |f|
        dest_dir = succesful_transfer_dir + File.dirname(f)
        FileUtils.mkdir_p(dest_dir)
        logger.debug "Moving #{f} to #{dest_dir}/#{File.basename(f)}"
        FileUtils.mv "#{src_dir}#{f}", dest_dir
        move_results << MoveResult.new("#{src_dir}#{f}", "#{dest_dir}/#{File.basename(f)}")
      end
      move_results
    end

    # Sends email for the given script_result
    def send_mail(config_hash, script_result)
      Email.send_mail(config_hash, script_result)
    end
  end
end
