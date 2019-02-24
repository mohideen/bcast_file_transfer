module BcastFileTransfer
  # Encapsulates the comparision results for a single destination
  class ComparisonResult
    attr_reader :dest_directory, :src_dir, :result, :transfer_files

    def initialize(dest_directory, src_dir, result, transfer_files)
      @dest_directory = dest_directory
      @src_dir = src_dir
      @result = result
      @transfer_files = transfer_files
    end

    def success?
      success = false
      if @result.respond_to? 'success?'
        success = @result.success?
      elsif @result.respond_to? 'successful?'
        success = @result.successful?
      end
      success
    end

    def error
      @result.error
    end
  end
end
