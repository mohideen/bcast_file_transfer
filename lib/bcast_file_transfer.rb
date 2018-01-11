require 'bcast_file_transfer/version'

# Loads all required classes
module BcastFileTransfer
  require 'bcast_file_transfer/logging'
  require 'bcast_file_transfer/script_result'
  require 'bcast_file_transfer/server_result'
  require 'bcast_file_transfer/comparison_result'
  require 'bcast_file_transfer/transfer_result'
  require 'bcast_file_transfer/move_result'
  require 'bcast_file_transfer/prune_result'
  require 'bcast_file_transfer/bcast_file_transfer'
  require 'bcast_file_transfer/email'
  require 'bcast_file_transfer/opt_parse'
end
